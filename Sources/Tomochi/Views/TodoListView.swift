import SwiftUI

struct TodoListView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var pomodoro: PomodoroTimer
    let selection: SidebarItem

    @State private var newTitle = ""
    @State private var editingTodo: TodoItem?
    @FocusState private var addFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 8) {
                    addCard
                    ForEach(filteredTodos) { todo in
                        TodoCard(todo: todo, onEdit: { editingTodo = todo })
                    }
                    if filteredTodos.isEmpty {
                        emptyState
                    }
                }
                .padding(14)
            }
            .background(
                ZStack {
                    Color(nsColor: .windowBackgroundColor)
                    Color.primary.opacity(0.045)
                }
            )

            Divider()
            HStack {
                Label("\(store.todayFocusMinutes) min focused today", systemImage: "timer")
                Text("·")
                Label("\(store.todayCompletedWorkSessions) pomodoros", systemImage: "cat")
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(.bar)
        }
        .navigationTitle(title)
        .sheet(item: $editingTodo) { todo in
            TodoEditView(todo: todo)
                .environmentObject(store)
        }
    }

    private var addCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
            TextField("Add a task…", text: $newTitle)
                .textFieldStyle(.plain)
                .focused($addFieldFocused)
                .onSubmit(addTodo)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            addFieldFocused ? Color.accentColor.opacity(0.5) : Color.primary.opacity(0.06),
                            style: StrokeStyle(lineWidth: 1, dash: addFieldFocused ? [] : [5])
                        )
                )
        )
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "cat")
                .font(.system(size: 42))
                .foregroundStyle(.tertiary)
            Text(selection == .completed ? "Nothing completed yet" : "All clear")
                .foregroundStyle(.secondary)
        }
        .padding(.top, 60)
    }

    private var title: String {
        switch selection {
        case .all: return "All"
        case .today: return "Today"
        case .completed: return "Completed"
        case .notes: return "Notes"
        case .category(let id):
            return store.categories.first { $0.id == id }?.name ?? "Category"
        }
    }

    private var filteredTodos: [TodoItem] {
        let active: [TodoItem]
        switch selection {
        case .all:
            active = store.todos.filter { !$0.isCompleted }
        case .today:
            active = store.todos.filter { todo in
                guard !todo.isCompleted, let due = todo.dueDate else { return false }
                return Calendar.current.isDateInToday(due) || due < Date()
            }
        case .completed, .notes:
            return store.todos
                .filter(\.isCompleted)
                .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        case .category(let id):
            active = store.todos.filter { $0.categoryId == id && !$0.isCompleted }
        }
        return active.sorted {
            if $0.priority != $1.priority {
                return rank($0.priority) < rank($1.priority)
            }
            return $0.createdAt > $1.createdAt
        }
    }

    private func rank(_ p: Priority) -> Int {
        switch p {
        case .high: return 0
        case .normal: return 1
        case .low: return 2
        }
    }

    private func addTodo() {
        let title = newTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        var categoryId: UUID?
        if case .category(let id) = selection { categoryId = id }
        var todo = TodoItem(title: title, categoryId: categoryId)
        if selection == .today {
            todo.dueDate = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date())
        }
        store.addTodo(todo)
        newTitle = ""
    }
}

/// A todo rendered as a ticket-style card: priority color spine on the left,
/// title + metadata chips, quick pomodoro action on hover.
struct TodoCard: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var pomodoro: PomodoroTimer
    let todo: TodoItem
    let onEdit: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            Capsule()
                .fill(todo.isCompleted ? Color.green.opacity(0.5) : todo.priority.color)
                .frame(width: 4)

            Button {
                withAnimation(.snappy) { store.toggleComplete(todo) }
            } label: {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(todo.isCompleted ? .green : Color(nsColor: .tertiaryLabelColor))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 5) {
                Text(todo.title)
                    .fontWeight(.medium)
                    .strikethrough(todo.isCompleted)
                    .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    if let category = store.category(for: todo) {
                        Chip(text: category.name, icon: category.icon, color: category.color)
                    }
                    if let due = todo.dueDate {
                        Chip(
                            text: due.formatted(.dateTime.month(.abbreviated).day().hour().minute()),
                            icon: "calendar",
                            color: due < Date() && !todo.isCompleted ? .red : .secondary
                        )
                    }
                    if !todo.notes.isEmpty {
                        Image(systemName: "note.text")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer(minLength: 8)

            if hovering && !todo.isCompleted {
                Button {
                    pomodoro.linkedTodo = todo
                    pomodoro.reset()
                    pomodoro.start()
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .help("Start a pomodoro for this task")
                .transition(.opacity)
            }
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(hovering ? 0.10 : 0.05), radius: hovering ? 4 : 2, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.primary.opacity(0.06))
        )
        .opacity(todo.isCompleted ? 0.65 : 1)
        .onHover { h in
            withAnimation(.easeOut(duration: 0.12)) { hovering = h }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onEdit)
        .contextMenu {
            Button("Edit") { onEdit() }
            Menu("Move to") {
                Button("Uncategorized") { move(to: nil) }
                ForEach(store.categories) { category in
                    Button(category.name) { move(to: category.id) }
                }
            }
            Menu("Priority") {
                ForEach(Priority.allCases) { p in
                    Button(p.label) {
                        var t = todo
                        t.priority = p
                        store.updateTodo(t)
                    }
                }
            }
            Divider()
            Button("Delete", role: .destructive) { store.deleteTodo(todo) }
        }
    }

    private func move(to categoryId: UUID?) {
        var t = todo
        t.categoryId = categoryId
        store.updateTodo(t)
    }
}

struct Chip: View {
    let text: String
    var icon: String?
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 9))
            }
            Text(text)
                .font(.caption2)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 2.5)
        .background(color.opacity(0.14), in: Capsule())
        .foregroundStyle(color)
    }
}

struct TodoEditView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    @State var todo: TodoItem
    @State private var hasDueDate: Bool

    init(todo: TodoItem) {
        _todo = State(initialValue: todo)
        _hasDueDate = State(initialValue: todo.dueDate != nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Title", text: $todo.title)
                .font(.title3)
                .textFieldStyle(.roundedBorder)

            HStack {
                Picker("Category", selection: $todo.categoryId) {
                    Text("None").tag(UUID?.none)
                    ForEach(store.categories) { category in
                        Text(category.name).tag(UUID?.some(category.id))
                    }
                }
                Picker("Priority", selection: $todo.priority) {
                    ForEach(Priority.allCases) { p in
                        Text(p.label).tag(p)
                    }
                }
            }

            Toggle("Due date", isOn: $hasDueDate)
            if hasDueDate {
                DatePicker(
                    "Due",
                    selection: Binding(
                        get: { todo.dueDate ?? Date() },
                        set: { todo.dueDate = $0 }
                    )
                )
            }

            Text("Notes")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $todo.notes)
                .font(.body)
                .frame(minHeight: 100)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))

            HStack {
                Button("Delete", role: .destructive) {
                    store.deleteTodo(todo)
                    dismiss()
                }
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    if !hasDueDate { todo.dueDate = nil }
                    else if todo.dueDate == nil { todo.dueDate = Date() }
                    store.updateTodo(todo)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}
