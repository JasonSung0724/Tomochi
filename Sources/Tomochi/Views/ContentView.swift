import SwiftUI

/// Sidebar selection: smart lists or a specific category.
enum SidebarItem: Hashable {
    case all
    case today
    case completed
    case notes
    case category(UUID)
}

struct ContentView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var pomodoro: PomodoroTimer
    @EnvironmentObject var chat: AIChatModel

    @State private var selection: SidebarItem? =
        ProcessInfo.processInfo.environment["TOMOCHI_START_TAB"] == "notes" ? .notes : .all
    @State private var showAIPanel = true
    @State private var showPomodoro = false
    @State private var showOnboarding = false
    @State private var searchText = ""
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 180, ideal: 210)
        } detail: {
            VStack(spacing: 0) {
                if let error = store.loadError {
                    ErrorBanner(text: error)
                }
                PomodoroBar(showFull: $showPomodoro)
                Divider()
                if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                    SearchResultsView(
                        query: searchText.trimmingCharacters(in: .whitespaces),
                        selection: $selection
                    )
                } else if selection == .notes {
                    NotesView()
                } else {
                    TodoListView(selection: selection ?? .all)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search tasks and notes")
        .inspector(isPresented: $showAIPanel) {
            AIChatView()
                .inspectorColumnWidth(min: 280, ideal: 340, max: 480)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAIPanel.toggle()
                } label: {
                    Label("AI Assistant", systemImage: "sparkles")
                }
                .help("Toggle the AI assistant panel")
            }
        }
        .sheet(isPresented: $showPomodoro) {
            PomodoroView()
                .environmentObject(pomodoro)
                .environmentObject(store)
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
        }
        .onAppear {
            switch ProcessInfo.processInfo.environment["TOMOCHI_ONBOARDING"] {
            case "force": showOnboarding = true
            case "skip": break
            default: if !hasCompletedOnboarding { showOnboarding = true }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showSetupAssistant)) { _ in
            showOnboarding = true
        }
    }
}

struct ErrorBanner: View {
    @EnvironmentObject var store: DataStore
    let text: String

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(text)
                .font(.callout)
                .lineLimit(2)
            Spacer()
            Button("Reload") { store.reloadFromDisk() }
        }
        .padding(8)
        .background(.yellow.opacity(0.15))
    }
}
