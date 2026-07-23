import SwiftUI

/// Cross-data search: tasks by title/notes/category, notes by content.
struct SearchResultsView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var notesStore: NotesStore
    @EnvironmentObject var pomodoro: PomodoroTimer
    let query: String
    @Binding var selection: SidebarItem?

    @State private var editingTodo: TodoItem?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                let todos = matchingTodos
                let notes = notesStore.search(query)

                if todos.isEmpty && notes.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 36, weight: .light))
                            .foregroundStyle(.tertiary)
                        Text("No results for “\(query)”")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 70)
                }

                if !todos.isEmpty {
                    SearchSectionHeader(title: "Tasks", count: todos.count)
                    ForEach(todos) { todo in
                        TodoCard(
                            todo: todo,
                            category: store.category(for: todo),
                            onEdit: { editingTodo = todo },
                            onStartFocus: {
                                pomodoro.linkedTodo = todo
                                pomodoro.reset()
                                pomodoro.start()
                            }
                        )
                    }
                }

                if !notes.isEmpty {
                    SearchSectionHeader(title: "Notes", count: notes.count)
                    ForEach(notes, id: \.note.filename) { result in
                        Button {
                            notesStore.pendingOpen = result.note.filename
                            selection = .notes
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "note.text")
                                    .foregroundStyle(Theme.accent)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(result.note.title)
                                        .font(.system(.body, design: .rounded, weight: .medium))
                                        .foregroundStyle(.primary)
                                    if !result.snippet.isEmpty {
                                        Text(result.snippet)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 11)
                            .padding(.horizontal, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .cardStyle()
                    }
                }
            }
            .padding(14)
        }
        .background(Theme.canvas)
        .sheet(item: $editingTodo) { todo in
            TodoEditView(todo: todo)
                .environmentObject(store)
        }
    }

    private var matchingTodos: [TodoItem] {
        let q = query.lowercased()
        return store.todos.filter { todo in
            todo.title.lowercased().contains(q)
                || todo.notes.lowercased().contains(q)
                || (store.category(for: todo)?.name.lowercased().contains(q) ?? false)
                || todo.tags.contains { $0.lowercased().contains(q) }
        }
    }
}

private struct SearchSectionHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("\(count)")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Color.primary.opacity(0.08), in: Capsule())
                .foregroundStyle(.secondary)
        }
        .padding(.top, 6)
    }
}
