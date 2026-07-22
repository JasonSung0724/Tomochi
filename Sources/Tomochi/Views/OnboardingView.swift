import SwiftUI
import AppKit
import UserNotifications

extension Notification.Name {
    static let showSetupAssistant = Notification.Name("showSetupAssistant")
}

/// Live status for the setup assistant's checklist.
@MainActor
final class SetupChecks: ObservableObject {
    enum NotifState { case unavailable, notDetermined, denied, authorized }
    enum InstallLocation { case ok, translocated, elsewhere, devBuild }

    @Published var notif: NotifState = .unavailable
    @Published var claudeInstalled = false
    @Published var codexInstalled = false

    private var hasBundle: Bool { Bundle.main.bundleIdentifier != nil }

    var installLocation: InstallLocation {
        guard hasBundle else { return .devBuild }
        let path = Bundle.main.bundlePath
        if path.contains("/AppTranslocation/") { return .translocated }
        if path.hasPrefix("/Applications") { return .ok }
        return .elsewhere
    }

    func refresh() {
        claudeInstalled = AIProviderKind.claude.isInstalled
        codexInstalled = AIProviderKind.codex.isInstalled
        guard hasBundle else {
            notif = .unavailable
            return
        }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                switch settings.authorizationStatus {
                case .notDetermined: self.notif = .notDetermined
                case .denied: self.notif = .denied
                default: self.notif = .authorized
                }
            }
        }
    }

    func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
            Task { @MainActor in self.refresh() }
        }
    }

    func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// Three-step first-launch wizard: welcome → checklist → try it.
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var checks = SetupChecks()
    @State private var page =
        Int(ProcessInfo.processInfo.environment["TOMOCHI_ONBOARDING_PAGE"] ?? "") ?? 0

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch page {
                case 0: welcome
                case 1: checklist
                default: tryIt
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            HStack {
                if page > 0 {
                    Button("Back") { page -= 1 }
                }
                Spacer()
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(i == page ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 7, height: 7)
                    }
                }
                Spacer()
                if page < 2 {
                    Button("Continue") { page += 1 }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("Start using Tomochi") {
                        hasCompletedOnboarding = true
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(14)
        }
        .frame(width: 560, height: 460)
        .onAppear { checks.refresh() }
    }

    // MARK: - Page 1: welcome

    private var welcome: some View {
        VStack(spacing: 14) {
            Text("🐱")
                .font(.system(size: 72))
            Text("Welcome to Tomochi")
                .font(.largeTitle.bold())
            Text("Todos, focus sessions, and notes —\nwith an AI assistant that does the busywork for you.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(30)
    }

    // MARK: - Page 2: checklist

    private var checklist: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Quick setup")
                .font(.title2.bold())

            locationRow
            notificationRow
            aiRow

            Spacer()
            HStack {
                Spacer()
                Button {
                    checks.refresh()
                } label: {
                    Label("Check again", systemImage: "arrow.clockwise")
                }
                .controlSize(.small)
            }
        }
        .padding(24)
    }

    @ViewBuilder
    private var locationRow: some View {
        switch checks.installLocation {
        case .ok:
            CheckRow(icon: "folder", title: "Installed in Applications", state: .ok)
        case .devBuild:
            CheckRow(icon: "folder", title: "Development build", state: .ok, detail: "Running outside an app bundle — notifications and auto-update are disabled.")
        case .translocated:
            CheckRow(icon: "folder", title: "Move Tomochi to Applications", state: .action,
                     detail: "macOS is running Tomochi from a temporary location, so auto-updates can't work. Quit, drag Tomochi.app into Applications in Finder, and reopen it.")
        case .elsewhere:
            CheckRow(icon: "folder", title: "Move Tomochi to Applications", state: .warn,
                     detail: "Auto-updates work best from /Applications.")
        }
    }

    @ViewBuilder
    private var notificationRow: some View {
        switch checks.notif {
        case .authorized:
            CheckRow(icon: "bell", title: "Notifications enabled", state: .ok)
        case .notDetermined:
            CheckRow(icon: "bell", title: "Enable notifications", state: .action,
                     detail: "Get notified when a focus session or break ends.") {
                Button("Enable") { checks.requestNotifications() }
                    .controlSize(.small)
            }
        case .denied:
            CheckRow(icon: "bell", title: "Notifications are off", state: .warn,
                     detail: "Pomodoro alerts will only play a sound.") {
                Button("Open System Settings") { checks.openNotificationSettings() }
                    .controlSize(.small)
            }
        case .unavailable:
            EmptyView()
        }
    }

    @ViewBuilder
    private var aiRow: some View {
        if checks.claudeInstalled || checks.codexInstalled {
            CheckRow(icon: "sparkles",
                     title: "AI engine ready (\(installedEngines))",
                     state: .ok,
                     detail: "If you haven't signed in yet, run `claude` once in Terminal.")
        } else {
            CheckRow(icon: "sparkles", title: "Install an AI engine", state: .action,
                     detail: "Tomochi's assistant runs on the Claude Code CLI — free of API keys, billed to your existing Claude account. Install, then run `claude` once to sign in. You can skip this and set it up later.") {
                CopyCommandField(command: "curl -fsSL https://claude.ai/install.sh | bash")
            }
        }
    }

    private var installedEngines: String {
        [checks.claudeInstalled ? "Claude Code" : nil,
         checks.codexInstalled ? "Codex" : nil]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    // MARK: - Page 3: try it

    private var tryIt: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Try asking the AI")
                .font(.title2.bold())
            VStack(alignment: .leading, spacing: 8) {
                ExamplePrompt(text: "I need to finish the report by Friday and buy cat food")
                ExamplePrompt(text: "Mark everything about the report as high priority")
                ExamplePrompt(text: "How long did I focus today?")
            }
            Text("The AI files tasks into your categories and remembers your habits — correct it once and it learns.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Divider()
            Label("Your cat lives in the menu bar — start a focus session from any app.", systemImage: "cat.fill")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Components

private struct CheckRow<Action: View>: View {
    enum RowState { case ok, warn, action }

    let icon: String
    let title: String
    let state: RowState
    var detail: String?
    @ViewBuilder var action: () -> Action

    init(icon: String, title: String, state: RowState, detail: String? = nil,
         @ViewBuilder action: @escaping () -> Action = { EmptyView() }) {
        self.icon = icon
        self.title = title
        self.state = state
        self.detail = detail
        self.action = action
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 26)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(title)
                        .fontWeight(.medium)
                    statusBadge
                }
                if let detail {
                    Text(LocalizedStringKey(detail))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                action()
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.primary.opacity(0.06))
        )
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch state {
        case .ok:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .warn:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.yellow)
        case .action:
            Image(systemName: "arrow.right.circle.fill")
                .foregroundStyle(Color.accentColor)
        }
    }
}

private struct CopyCommandField: View {
    let command: String
    @State private var copied = false

    var body: some View {
        HStack(spacing: 8) {
            Text(command)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(command, forType: .string)
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(.plain)
            .foregroundStyle(copied ? .green : .secondary)
            .help("Copy")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct ExamplePrompt: View {
    let text: String

    var body: some View {
        Text("“\(text)”")
            .font(.callout)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}
