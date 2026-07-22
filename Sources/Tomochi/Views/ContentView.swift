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
                if selection == .notes {
                    NotesView()
                } else {
                    TodoListView(selection: selection ?? .all)
                }
            }
        }
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
