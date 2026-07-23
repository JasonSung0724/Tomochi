import SwiftUI

struct TodoListView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var pomodoro: PomodoroTimer
    let selection: SidebarItem

    @State private var editingTodo: TodoItem?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 8) {
                    AddTaskField { title in addTodo(title) }
                    ForEach(filteredTodos) { todo in
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
                    if filteredTodos.isEmpty {
                        emptyState
                    }
                }
                .padding(14)
            }
            .background(Theme.canvas)

            Divider()
            StatsFooter()
        }
        .navigationTitle(title)
        .sheet(item: $editingTodo) { todo in
            TodoEditView(todo: todo)
                .environmentObject(store)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "cat")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Theme.accent.opacity(0.55))
            Text(selection == .completed ? "Nothing completed yet" : "All clear")
                .font(.system(.title3, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 70)
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

    private func addTodo(_ title: String) {
        var categoryId: UUID?
        if case .category(let id) = selection { categoryId = id }
        var todo = TodoItem(title: title, categoryId: categoryId)
        if selection == .today {
            todo.dueDate = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date())
        }
        store.addTodo(todo)
    }
}

/// Isolated so keystrokes don't re-render the whole card list.
private struct AddTaskField: View {
    let onSubmit: (String) -> Void
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundStyle(Theme.accent)
            TextField("Add a task…", text: $text)
                .textFieldStyle(.plain)
                .focused($focused)
                .onSubmit {
                    let title = text.trimmingCharacters(in: .whitespaces)
                    guard !title.isEmpty else { return }
                    onSubmit(title)
                    text = ""
                }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.cardBackground.opacity(focused ? 1 : 0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    focused ? Theme.accent.opacity(0.5) : Theme.hairline,
                    style: StrokeStyle(lineWidth: 1, dash: focused ? [] : [5, 4])
                )
        )
    }
}

/// Bottom stats bar — the only list-adjacent view that observes the store's
/// session data, so pomodoro ticks never touch the cards above.
private struct StatsFooter: View {
    @EnvironmentObject var store: DataStore

    var body: some View {
        HStack(spacing: 8) {
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
}

/// A todo as a ticket-style card. Deliberately does NOT observe the pomodoro
/// timer — with it in the environment, every card re-rendered on every tick.
struct TodoCard: View {
    @EnvironmentObject var store: DataStore
    let todo: TodoItem
    let category: TodoCategory?
    let onEdit: () -> Void
    let onStartFocus: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            Capsule()
                .fill(todo.isCompleted ? Color.green.opacity(0.45) : todo.priority.color)
                .frame(width: 4)

            CheckToggle(isOn: todo.isCompleted) {
                withAnimation(.snappy) { store.toggleComplete(todo) }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(todo.title)
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .strikethrough(todo.isCompleted)
                    .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    if let category {
                        Chip(text: category.name, icon: category.icon, color: category.color)
                    }
                    if let due = todo.dueDate {
                        Chip(
                            text: due.formatted(.dateTime.month(.abbreviated).day().hour().minute()),
                            icon: "calendar",
                            color: due < Date() && !todo.isCompleted ? Theme.priorityHigh : .secondary
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
                Button(action: onStartFocus) {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
                .help("Start a pomodoro for this task")
            }
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 12)
        .cardStyle(highlighted: hovering)
        .opacity(todo.isCompleted ? 0.6 : 1)
        .onHover { hovering = $0 }
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

/// Springy circular checkbox.
private struct CheckToggle: View {
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .strokeBorder(isOn ? Color.clear : Color(nsColor: .tertiaryLabelColor),
                                  lineWidth: 1.5)
                    .background(Circle().fill(isOn ? Color.green : Color.clear))
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 20, height: 20)
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.25), value: isOn)
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
                .font(.caption2.weight(.medium))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 2.5)
        .background(color.opacity(0.13), in: Capsule())
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
                .font(.system(.title3, design: .rounded))
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
