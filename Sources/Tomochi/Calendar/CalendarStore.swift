import Foundation
import EventKit
import SwiftUI
import Combine

/// EventKit bridge. The user's macOS Calendar (including signed-in Google
/// accounts) is the source of truth; this store:
///  - shows events for the selected day in the Calendar tab
///  - mirrors -7d…+30d of events to `data/calendar.json` so the AI can read
///    the schedule
///  - watches `data/calendar-outbox.json` for event requests written by the
///    AI and turns them into real calendar events
@MainActor
final class CalendarStore: ObservableObject {
    enum AuthState {
        case unknown       // not asked yet
        case unavailable   // dev build without an app bundle (no TCC identity)
        case denied
        case authorized
    }

    struct OutboxRequest: Codable {
        var title: String
        var startDate: Date
        var endDate: Date?
        var isAllDay: Bool?
        var notes: String?
        var location: String?
    }

    private struct OutboxFile: Codable {
        var version: Int = 1
        var requests: [OutboxRequest] = []
    }

    private struct MirrorEvent: Codable {
        var id: String
        var title: String
        var startDate: Date
        var endDate: Date
        var isAllDay: Bool
        var calendar: String
        var location: String?
    }

    private struct MirrorFile: Codable {
        var version: Int = 1
        var note: String
        var events: [MirrorEvent] = []
    }

    @Published var auth: AuthState = .unknown
    @Published var selectedDate = Date()
    @Published var dayEvents: [EKEvent] = []
    @Published var upcomingEvents: [EKEvent] = []
    @Published var lastError: String?

    private let eventStore = EKEventStore()
    private var outboxWatcher: FileWatcher?
    private var suppressOutboxUntil = Date.distantPast
    private var cancellables: Set<AnyCancellable> = []

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init() {
        if Bundle.main.bundleIdentifier == nil {
            auth = .unavailable
        } else {
            switch EKEventStore.authorizationStatus(for: .event) {
            case .fullAccess: auth = .authorized
            case .denied, .restricted, .writeOnly: auth = .denied
            default: auth = .unknown
            }
        }
        ensureOutboxExists()
        if auth == .authorized { refresh() }

        NotificationCenter.default.publisher(for: .EKEventStoreChanged, object: eventStore)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        outboxWatcher = FileWatcher(url: Paths.dataDir) { [weak self] in
            guard let self, Date() > self.suppressOutboxUntil else { return }
            self.processOutbox()
        }

        $selectedDate
            .removeDuplicates()
            .sink { [weak self] date in self?.loadDayEvents(for: date) }
            .store(in: &cancellables)
    }

    func requestAccess() {
        guard auth == .unknown else { return }
        eventStore.requestFullAccessToEvents { [weak self] granted, _ in
            Task { @MainActor in
                self?.auth = granted ? .authorized : .denied
                if granted { self?.refresh() }
            }
        }
    }

    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Reading

    func refresh() {
        guard auth == .authorized else { return }
        loadDayEvents(for: selectedDate)
        loadUpcoming()
        exportMirror()
        processOutbox()
    }

    /// The next 7 days (excluding today), for the sidebar rail.
    private func loadUpcoming() {
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date())),
              let end = cal.date(byAdding: .day, value: 7, to: start) else { return }
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        upcomingEvents = Array(
            eventStore.events(matching: predicate)
                .sorted { $0.startDate < $1.startDate }
                .prefix(8)
        )
    }

    private func loadDayEvents(for date: Date) {
        guard auth == .authorized else { return }
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return }
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        dayEvents = eventStore.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
    }

    /// Todos from the app that are due on the selected day.
    func dueTodos(from store: DataStore) -> [TodoItem] {
        let cal = Calendar.current
        return store.todos.filter { todo in
            guard let due = todo.dueDate, !todo.isCompleted else { return false }
            return cal.isDate(due, inSameDayAs: selectedDate)
        }
    }

    // MARK: - Creating events

    func addEvent(title: String, start: Date, end: Date, isAllDay: Bool,
                  notes: String? = nil, location: String? = nil) -> Bool {
        guard auth == .authorized else { return false }
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = start
        event.endDate = end
        event.isAllDay = isAllDay
        event.notes = notes
        event.location = location
        event.calendar = eventStore.defaultCalendarForNewEvents
        do {
            try eventStore.save(event, span: .thisEvent, commit: true)
            refresh()
            return true
        } catch {
            lastError = "Couldn't save the event: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - AI file bridge

    private func ensureOutboxExists() {
        guard !FileManager.default.fileExists(atPath: Paths.calendarOutboxFile.path) else { return }
        writeOutbox(OutboxFile())
    }

    private func writeOutbox(_ outbox: OutboxFile) {
        suppressOutboxUntil = Date().addingTimeInterval(1.0)
        if let data = try? Self.encoder.encode(outbox) {
            try? data.write(to: Paths.calendarOutboxFile, options: .atomic)
        }
    }

    /// Turns AI-written outbox requests into real calendar events.
    private func processOutbox() {
        guard auth == .authorized,
              let data = try? Data(contentsOf: Paths.calendarOutboxFile),
              let outbox = try? Self.decoder.decode(OutboxFile.self, from: data),
              !outbox.requests.isEmpty
        else { return }

        for request in outbox.requests {
            let start = request.startDate
            let end = request.endDate
                ?? Calendar.current.date(byAdding: .hour, value: 1, to: start)
                ?? start.addingTimeInterval(3600)
            _ = addEvent(
                title: request.title,
                start: start,
                end: end,
                isAllDay: request.isAllDay ?? false,
                notes: request.notes,
                location: request.location
            )
        }
        writeOutbox(OutboxFile())
        exportMirror()
    }

    /// Writes -7d…+30d of events to data/calendar.json for the AI to read.
    private func exportMirror() {
        guard auth == .authorized else { return }
        let cal = Calendar.current
        let now = Date()
        guard let start = cal.date(byAdding: .day, value: -7, to: now),
              let end = cal.date(byAdding: .day, value: 30, to: now) else { return }
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = eventStore.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .map {
                MirrorEvent(
                    id: $0.eventIdentifier ?? UUID().uuidString,
                    title: $0.title ?? "",
                    startDate: $0.startDate,
                    endDate: $0.endDate,
                    isAllDay: $0.isAllDay,
                    calendar: $0.calendar?.title ?? "",
                    location: $0.location
                )
            }
        let mirror = MirrorFile(
            note: "Read-only mirror of the user's calendar (-7d…+30d), regenerated by the app. To create events, write to calendar-outbox.json instead.",
            events: events
        )
        if let data = try? Self.encoder.encode(mirror) {
            try? data.write(to: Paths.calendarMirrorFile, options: .atomic)
        }
    }
}

extension EKEvent {
    var displayColor: Color {
        guard let cgColor = calendar?.cgColor else { return Theme.accent }
        return Color(cgColor: cgColor)
    }
}
