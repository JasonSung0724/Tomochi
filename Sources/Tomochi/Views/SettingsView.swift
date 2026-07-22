import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var pomodoro: PomodoroTimer
    @EnvironmentObject var chat: AIChatModel

    var body: some View {
        TabView {
            pomodoroTab
                .tabItem { Label("Pomodoro", systemImage: "timer") }
            aiTab
                .tabItem { Label("AI", systemImage: "sparkles") }
            dataTab
                .tabItem { Label("Data", systemImage: "folder") }
        }
        .frame(width: 420, height: 260)
    }

    private var pomodoroTab: some View {
        Form {
            Stepper("Focus: \(pomodoro.workMinutes) min",
                    value: $pomodoro.workMinutes, in: 5...90, step: 5)
            Stepper("Short break: \(pomodoro.shortBreakMinutes) min",
                    value: $pomodoro.shortBreakMinutes, in: 1...30)
            Stepper("Long break: \(pomodoro.longBreakMinutes) min",
                    value: $pomodoro.longBreakMinutes, in: 5...60, step: 5)
            Stepper("Long break every \(pomodoro.longBreakEvery) pomodoros",
                    value: $pomodoro.longBreakEvery, in: 2...8)
        }
        .padding(20)
    }

    private var aiTab: some View {
        Form {
            Picker("Provider", selection: $chat.provider) {
                ForEach(AIProviderKind.allCases) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
            ForEach(AIProviderKind.allCases) { kind in
                LabeledContent(kind.displayName) {
                    if kind.isInstalled {
                        Label("Installed", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("`\(kind.executableName)` CLI not found", systemImage: "xmark.circle")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(20)
    }

    private var dataTab: some View {
        Form {
            LabeledContent("Location") {
                Text(Paths.workspace.path)
                    .font(.caption)
                    .textSelection(.enabled)
                    .lineLimit(3)
            }
            Button("Open in Finder") {
                NSWorkspace.shared.open(Paths.workspace)
            }
            Text("All data is plain JSON/Markdown. The AI reads and edits these files directly; memory/MEMORY.md holds what it has learned about you.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }
}
