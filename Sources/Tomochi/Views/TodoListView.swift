import SwiftUI

struct TodoListView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var pomodoro: PomodoroTimer
    let selection: SidebarItem

    @State private var newTitle = ""
    @State private var editingTodo: TodoItem?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.secondary)
                TextField("Add a task…", text: $newTitle)
                    .textFieldStyle(.plain)
                    .onSubmit(addTodo)
            }
            .padding(10)

            Divider()

            if filteredTodos.isEmpty {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: "cat"
                )
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredTodos) { todo in
                        TodoRowView(
                            todo: todo,
                            onEdit: { editingTodo = todo }
                        )
                    }
                }
                .listStyle(.inset)
            }

            Divider()
            HStack {
                Text("Today: \(store.todayFocusMinutes) min focused · \(store.todayCompletedWorkSessions) pomodoros")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .navigationTitle(title)
        .sheet(item: $editingTodo) { todo in
            TodoEditView(todo: todo)
                .environmentObject(store)
        }
    }

    private var title: String {
        switch selection {
        case .all: return "All"
        case .today: return "Today"
        case .completed: return "Completed"
        case .category(let id):
            return store.categories.first { $0.id == id }?.name ?? "Category"
        }
    }

    private var emptyTitle: String {
        selection == .completed ? "Nothing completed yet" : "No tasks"
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
        case .completed:
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

struct TodoRowView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var pomodoro: PomodoroTimer
    let todo: TodoItem
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button {
                store.toggleComplete(todo)
            } label: {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(todo.isCompleted ? .green : Color(nsColor: .tertiaryLabelColor))
            }
            .buttonStyle(.plain)

            Circle()
                .fill(todo.priority.color)
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 2) {
                Text(todo.title)
                    .strikethrough(todo.isCompleted)
                    .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                HStack(spacing: 6) {
                    if let category = store.category(for: todo) {
                        Text(category.name)
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(category.color.opacity(0.18), in: Capsule())
                            .foregroundStyle(category.color)
                    }
                    if let due = todo.dueDate {
                        Label(due.formatted(.dateTime.month().day().hour().minute()),
                              systemImage: "calendar")
                            .font(.caption2)
                            .foregroundStyle(due < Date() && !todo.isCompleted ? .red : .secondary)
                    }
                    if !todo.notes.isEmpty {
                        Image(systemName: "note.text")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Button {
                pomodoro.linkedTodo = todo
                pomodoro.reset()
                pomodoro.start()
            } label: {
                Image(systemName: "timer")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Start a pomodoro for this task")
        }
        .padding(.vertical, 3)
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
