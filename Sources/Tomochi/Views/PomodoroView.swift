import SwiftUI

/// Slim always-visible bar at the top of the main window.
struct PomodoroBar: View {
    @EnvironmentObject var pomodoro: PomodoroTimer
    @Binding var showFull: Bool

    var body: some View {
        HStack(spacing: 12) {
            Button {
                showFull = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "timer")
                    Text("\(pomodoro.phase.label) \(pomodoro.remainingText)")
                        .font(.system(.body, design: .monospaced))
                }
            }
            .buttonStyle(.plain)

            if let todo = pomodoro.linkedTodo {
                Text("→ \(todo.title)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            ProgressView(value: pomodoro.progress)
                .frame(width: 120)

            if pomodoro.isRunning {
                Button("Pause") { pomodoro.pause() }
            } else {
                Button("Start") { pomodoro.start() }
                    .buttonStyle(.borderedProminent)
            }
            Button {
                pomodoro.reset()
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .help("Reset")
        }
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.bar)
    }
}

/// Full pomodoro sheet with the big dial.
struct PomodoroView: View {
    @EnvironmentObject var pomodoro: PomodoroTimer
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Text(pomodoro.phase.label)
                .font(.headline)
                .foregroundStyle(pomodoro.phase == .work ? .red : .green)

            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: pomodoro.progress)
                    .stroke(
                        pomodoro.phase == .work ? Color.red : Color.green,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: pomodoro.progress)
                Text(pomodoro.remainingText)
                    .font(.system(size: 42, weight: .light, design: .monospaced))
            }
            .frame(width: 200, height: 200)

            Picker("Task", selection: linkedTodoBinding) {
                Text("None").tag(UUID?.none)
                ForEach(store.todos.filter { !$0.isCompleted }) { todo in
                    Text(todo.title).tag(UUID?.some(todo.id))
                }
            }
            .frame(maxWidth: 300)

            HStack(spacing: 12) {
                if pomodoro.isRunning {
                    Button("Pause") { pomodoro.pause() }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Start") { pomodoro.start() }
                        .buttonStyle(.borderedProminent)
                }
                Button("Reset") { pomodoro.reset() }
                Button("Skip") { pomodoro.skipPhase() }
            }

            Text("Today: \(store.todayCompletedWorkSessions) pomodoros · \(store.todayFocusMinutes) min")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Close") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(28)
        .frame(width: 380)
    }

    private var linkedTodoBinding: Binding<UUID?> {
        Binding(
            get: { pomodoro.linkedTodo?.id },
            set: { id in
                pomodoro.linkedTodo = store.todos.first { $0.id == id }
            }
        )
    }
}
