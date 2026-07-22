import Foundation
import AppKit
import Combine
import UserNotifications

/// Pomodoro engine: work → short break, with a long break every N work
/// sessions. Completed work sessions are recorded to the data store.
@MainActor
final class PomodoroTimer: ObservableObject {
    enum Phase: String {
        case work, shortBreak, longBreak

        var label: String {
            switch self {
            case .work: return "Focus"
            case .shortBreak: return "Short Break"
            case .longBreak: return "Long Break"
            }
        }
    }

    @Published var phase: Phase = .work
    @Published var remainingSeconds: Int
    @Published var isRunning = false
    @Published var completedWorkCount = 0

    /// The todo being focused on, shown in UI and linked in session records.
    @Published var linkedTodo: TodoItem?

    // Settings (persisted in UserDefaults, editable in 設定).
    @Published var workMinutes: Int {
        didSet { UserDefaults.standard.set(workMinutes, forKey: "pomodoro.work"); resetIfIdle() }
    }
    @Published var shortBreakMinutes: Int {
        didSet { UserDefaults.standard.set(shortBreakMinutes, forKey: "pomodoro.short"); resetIfIdle() }
    }
    @Published var longBreakMinutes: Int {
        didSet { UserDefaults.standard.set(longBreakMinutes, forKey: "pomodoro.long"); resetIfIdle() }
    }
    @Published var longBreakEvery: Int {
        didSet { UserDefaults.standard.set(longBreakEvery, forKey: "pomodoro.every") }
    }

    private var timer: Timer?
    private var phaseStartedAt: Date?
    private weak var store: DataStore?

    init(store: DataStore) {
        self.store = store
        let d = UserDefaults.standard
        let work = d.integer(forKey: "pomodoro.work")
        let short = d.integer(forKey: "pomodoro.short")
        let long = d.integer(forKey: "pomodoro.long")
        let every = d.integer(forKey: "pomodoro.every")
        workMinutes = work > 0 ? work : 25
        shortBreakMinutes = short > 0 ? short : 5
        longBreakMinutes = long > 0 ? long : 15
        longBreakEvery = every > 0 ? every : 4
        remainingSeconds = (work > 0 ? work : 25) * 60
        requestNotificationPermissionIfBundled()
    }

    var remainingText: String {
        String(format: "%02d:%02d", remainingSeconds / 60, remainingSeconds % 60)
    }

    var progress: Double {
        let total = Double(duration(for: phase))
        guard total > 0 else { return 0 }
        return 1 - Double(remainingSeconds) / total
    }

    private func duration(for phase: Phase) -> Int {
        switch phase {
        case .work: return workMinutes * 60
        case .shortBreak: return shortBreakMinutes * 60
        case .longBreak: return longBreakMinutes * 60
        }
    }

    // MARK: - Controls

    func start() {
        guard !isRunning else { return }
        isRunning = true
        if phaseStartedAt == nil { phaseStartedAt = Date() }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    func reset() {
        pause()
        phaseStartedAt = nil
        remainingSeconds = duration(for: phase)
    }

    func skipPhase() {
        endPhase(completed: false)
    }

    private func resetIfIdle() {
        if !isRunning && phaseStartedAt == nil {
            remainingSeconds = duration(for: phase)
        }
    }

    private func tick() {
        guard isRunning else { return }
        remainingSeconds -= 1
        if remainingSeconds <= 0 {
            endPhase(completed: true)
        }
    }

    private func endPhase(completed: Bool) {
        pause()
        let ended = Date()
        let started = phaseStartedAt ?? ended
        phaseStartedAt = nil

        if phase == .work, started < ended {
            store?.recordSession(PomodoroSession(
                todoId: linkedTodo?.id,
                kind: .work,
                startedAt: started,
                endedAt: ended,
                completed: completed
            ))
            if completed { completedWorkCount += 1 }
        }

        let next: Phase
        switch phase {
        case .work:
            next = (completedWorkCount > 0 && completedWorkCount % longBreakEvery == 0)
                ? .longBreak : .shortBreak
        case .shortBreak, .longBreak:
            next = .work
        }

        if completed {
            notify(
                title: phase == .work ? "🐱 Focus complete!" : "Break over",
                body: phase == .work
                    ? "Time for a break (\(next.label), \(duration(for: next) / 60) min)"
                    : "Ready for the next focus session"
            )
        }

        phase = next
        remainingSeconds = duration(for: next)
    }

    // MARK: - Notifications

    private var hasBundle: Bool { Bundle.main.bundleIdentifier != nil }

    private func requestNotificationPermissionIfBundled() {
        guard hasBundle else { return }
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func notify(title: String, body: String) {
        NSSound(named: "Glass")?.play()
        guard hasBundle else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = nil
        let request = UNNotificationRequest(
            identifier: UUID().uuidString, content: content, trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
