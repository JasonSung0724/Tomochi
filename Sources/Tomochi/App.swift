import SwiftUI
import AppKit
import Sparkle

@main
struct TomochiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store: DataStore
    @StateObject private var pomodoro: PomodoroTimer
    @StateObject private var chat: AIChatModel
    @StateObject private var notesStore: NotesStore
    @StateObject private var calendarStore: CalendarStore

    init() {
        let store = DataStore()
        _store = StateObject(wrappedValue: store)
        _pomodoro = StateObject(wrappedValue: PomodoroTimer(store: store))
        _chat = StateObject(wrappedValue: AIChatModel(store: store))
        _notesStore = StateObject(wrappedValue: NotesStore())
        _calendarStore = StateObject(wrappedValue: CalendarStore())
    }

    var body: some Scene {
        WindowGroup("Tomochi") {
            ContentView()
                .environmentObject(store)
                .environmentObject(pomodoro)
                .environmentObject(chat)
                .environmentObject(notesStore)
                .environmentObject(calendarStore)
                .frame(minWidth: 760, minHeight: 480)
        }
        .defaultSize(width: 1080, height: 680)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    appDelegate.checkForUpdates()
                }
                .disabled(!appDelegate.canCheckForUpdates)
                Button("Setup Assistant…") {
                    NotificationCenter.default.post(name: .showSetupAssistant, object: nil)
                }
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
        warnIfTranslocated()
        snapshotIfRequested()
    }

    /// Dev tool: TOMOCHI_SNAPSHOT=/path.png renders the main window to a PNG
    /// (no screen-recording permission needed) and exits. Used for README shots.
    private func snapshotIfRequested() {
        guard let path = ProcessInfo.processInfo.environment["TOMOCHI_SNAPSHOT"] else { return }
        // Translucent materials render inconsistently offscreen; a fixed
        // appearance keeps the capture uniform (dark via TOMOCHI_SNAPSHOT_DARK).
        let dark = ProcessInfo.processInfo.environment["TOMOCHI_SNAPSHOT_DARK"] != nil
        NSApp.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            // Prefer an open sheet (e.g. the setup assistant) over the
            // window behind it.
            if let window = NSApp.windows.first(where: { $0.isSheet })
                ?? NSApp.keyWindow
                ?? NSApp.windows.max(by: { $0.frame.width < $1.frame.width }),
               let view = window.contentView,
               let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                view.cacheDisplay(in: view.bounds, to: rep)
                if let png = rep.representation(using: .png, properties: [:]) {
                    try? png.write(to: URL(fileURLWithPath: path))
                }
            }
            NSApp.terminate(nil)
        }
    }

    /// Gatekeeper runs quarantined apps from a randomized read-only path,
    /// which breaks Sparkle self-updates. Tell the user how to fix it.
    private func warnIfTranslocated() {
        // The first-launch setup assistant surfaces this itself.
        guard UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") else { return }
        guard Bundle.main.bundlePath.contains("/AppTranslocation/") else { return }
        let alert = NSAlert()
        alert.messageText = "Move Tomochi to Applications"
        alert.informativeText = "Tomochi is running from a temporary location (translocated by macOS), so automatic updates can't work. Quit, move Tomochi.app to /Applications in Finder, and launch it from there."
        alert.alertStyle = .warning
        alert.runModal()
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
