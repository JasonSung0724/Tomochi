import SwiftUI
import AppKit
import Sparkle

@main
struct TomochiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store: DataStore
    @StateObject private var pomodoro: PomodoroTimer
    @StateObject private var chat: AIChatModel

    init() {
        let store = DataStore()
        _store = StateObject(wrappedValue: store)
        _pomodoro = StateObject(wrappedValue: PomodoroTimer(store: store))
        _chat = StateObject(wrappedValue: AIChatModel(store: store))
    }

    var body: some Scene {
        WindowGroup("Tomochi") {
            ContentView()
                .environmentObject(store)
                .environmentObject(pomodoro)
                .environmentObject(chat)
                .frame(minWidth: 760, minHeight: 480)
        }
        .defaultSize(width: 1080, height: 680)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    appDelegate.checkForUpdates()
                }
                .disabled(!appDelegate.canCheckForUpdates)
            }
        }

        MenuBarExtra {
            MenuBarContent()
                .environmentObject(pomodoro)
        } label: {
            if pomodoro.isRunning || pomodoro.progress > 0 {
                Text("🐱 \(pomodoro.remainingText)")
            } else {
                Image(systemName: "cat.fill")
            }
        }

        Settings {
            SettingsView()
                .environmentObject(pomodoro)
                .environmentObject(chat)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var updater: SPUStandardUpdaterController?

    var canCheckForUpdates: Bool { updater != nil }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // When launched via `swift run` (no app bundle), the process defaults
        // to a background activation policy — force regular-app behavior.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        // Sparkle needs a real bundle; skip it for bare `swift run` binaries.
        if Bundle.main.bundleIdentifier != nil {
            updater = SPUStandardUpdaterController(
                startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil
            )
        }
    }

    func checkForUpdates() {
        updater?.checkForUpdates(nil)
    }
}

struct MenuBarContent: View {
    @EnvironmentObject var pomodoro: PomodoroTimer

    var body: some View {
        Text("\(pomodoro.phase.label) \(pomodoro.remainingText)")
        if let todo = pomodoro.linkedTodo {
            Text("Focusing: \(todo.title)")
        }
        Divider()
        if pomodoro.isRunning {
            Button("Pause") { pomodoro.pause() }
        } else {
            Button("Start") { pomodoro.start() }
        }
        Button("Reset") { pomodoro.reset() }
        Button("Skip Phase") { pomodoro.skipPhase() }
        Divider()
        Button("Quit Tomochi") { NSApp.terminate(nil) }
    }
}
