import SwiftUI
import EventKit

struct CalendarView: View {
    @EnvironmentObject var calendar: CalendarStore
    @EnvironmentObject var store: DataStore
    @State private var showAddEvent = false

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                DatePicker(
                    "",
                    selection: $calendar.selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()

                if calendar.auth == .authorized {
                    Divider()
                    Text("Upcoming")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(.secondary)
                    if calendar.upcomingEvents.isEmpty {
                        Text("Nothing in the next 7 days")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(calendar.upcomingEvents, id: \.eventIdentifier) { event in
                                    UpcomingRow(event: event) {
                                        calendar.selectedDate = event.startDate
                                    }
                                }
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(width: 280)

            Divider()

            agenda
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { calendar.requestAccess() }
    }

    @ViewBuilder
    private var agenda: some View {
        switch calendar.auth {
        case .authorized:
            authorizedAgenda
        case .unknown:
            CalendarMessage(
                icon: "calendar.badge.plus",
                title: "Connect your calendar",
                message: "Tomochi shows your schedule next to your tasks, and the AI can add events for you. Google Calendar syncs through the account you added in macOS Calendar."
            ) {
                Button("Allow Calendar Access") { calendar.requestAccess() }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
            }
        case .denied:
            CalendarMessage(
                icon: "calendar.badge.exclamationmark",
                title: "Calendar access is off",
                message: "Enable it in System Settings → Privacy & Security → Calendars."
            ) {
                Button("Open System Settings") { calendar.openPrivacySettings() }
            }
        case .unavailable:
            CalendarMessage(
                icon: "calendar",
                title: "Calendar needs the bundled app",
                message: "Development builds can't request calendar access. Run the installed Tomochi.app."
            ) { EmptyView() }
        }
    }

    private var authorizedAgenda: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text(calendar.selectedDate.formatted(.dateTime.weekday(.wide).month().day()))
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                if Calendar.current.isDateInToday(calendar.selectedDate) {
                    Text("Today")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Theme.accent.opacity(0.15), in: Capsule())
                        .foregroundStyle(Theme.accent)
                }
                Spacer()
                HStack(spacing: 2) {
                    Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                    Button("Today") { calendar.selectedDate = Date() }
                    Button { shift(1) } label: { Image(systemName: "chevron.right") }
                }
                .controlSize(.small)
                Button {
                    showAddEvent = true
                } label: {
                    Label("New Event", systemImage: "plus")
                }
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
            }
            .padding(12)
            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    let due = calendar.dueTodos(from: store)
                    if calendar.dayEvents.isEmpty && due.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "cat")
                                .font(.system(size: 38, weight: .light))
                                .foregroundStyle(Theme.accent.opacity(0.5))
                            Text("Nothing scheduled")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    }

                    ForEach(calendar.dayEvents, id: \.eventIdentifier) { event in
                        EventRow(event: event)
                    }

                    if !due.isEmpty {
                        Text("Tasks due")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.top, 6)
                        ForEach(due) { todo in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(todo.priority.color)
                                    .frame(width: 7, height: 7)
                                Text(todo.title)
                                    .font(.system(.body, design: .rounded))
                                Spacer()
                                if let dueDate = todo.dueDate {
                                    Text(dueDate.formatted(.dateTime.hour().minute()))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 9)
                            .padding(.horizontal, 12)
                            .cardStyle()
                        }
                    }
                }
                .padding(14)
            }
            .background(Theme.canvas)

            if let error = calendar.lastError {
                Divider()
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(8)
            }
        }
        .popover(isPresented: $showAddEvent, arrowEdge: .bottom) {
            AddEventForm(defaultDate: calendar.selectedDate)
                .environmentObject(calendar)
        }
    }

    private func shift(_ days: Int) {
        if let d = Calendar.current.date(byAdding: .day, value: days, to: calendar.selectedDate) {
            calendar.selectedDate = d
        }
    }
}

private struct UpcomingRow: View {
    let event: EKEvent
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Capsule()
                    .fill(event.displayColor)
                    .frame(width: 3, height: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text(event.title ?? "")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .lineLimit(1)
                    Text(event.startDate.formatted(.dateTime.weekday(.abbreviated).day().hour().minute()))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(4)
            .background(hovering ? Color.primary.opacity(0.05) : .clear,
                        in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

private struct CalendarMessage<Action: View>: View {
    let icon: String
    let title: String
    let message: String
    @ViewBuilder var action: () -> Action

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Theme.accent.opacity(0.6))
            Text(title)
                .font(.system(.title3, design: .rounded, weight: .semibold))
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            action()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background(Theme.canvas)
    }
}

private struct EventRow: View {
    let event: EKEvent

    var body: some View {
        HStack(spacing: 12) {
            Capsule()
                .fill(event.displayColor)
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 3) {
                Text(event.title ?? "")
                    .font(.system(.body, design: .rounded, weight: .medium))
                HStack(spacing: 6) {
                    if event.isAllDay {
                        Text("All day")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(event.startDate.formatted(.dateTime.hour().minute())) – \(event.endDate.formatted(.dateTime.hour().minute()))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let location = event.location, !location.isEmpty {
                        Label(location, systemImage: "mappin")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
            if let name = event.calendar?.title {
                Text(name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .cardStyle()
    }
}

private struct AddEventForm: View {
    @EnvironmentObject var calendar: CalendarStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var start: Date
    @State private var end: Date
    @State private var isAllDay = false

    init(defaultDate: Date) {
        let cal = Calendar.current
        let base = cal.date(bySettingHour: 9, minute: 0, second: 0, of: defaultDate) ?? defaultDate
        _start = State(initialValue: base)
        _end = State(initialValue: base.addingTimeInterval(3600))
        _title = State(initialValue: "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New Event")
                .font(.headline)
            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)
            Toggle("All day", isOn: $isAllDay)
            DatePicker("Starts", selection: $start,
                       displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
            if !isAllDay {
                DatePicker("Ends", selection: $end, in: start...,
                           displayedComponents: [.date, .hourAndMinute])
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Add") {
                    let trimmed = title.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    if calendar.addEvent(
                        title: trimmed,
                        start: start,
                        end: isAllDay ? start : max(end, start.addingTimeInterval(60)),
                        isAllDay: isAllDay
                    ) {
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
            }
        }
        .padding(16)
    }
}
