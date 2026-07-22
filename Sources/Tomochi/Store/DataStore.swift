import Foundation
import Combine

/// Single source of truth. Persists everything as pretty-printed JSON in the
/// AI workspace and reloads automatically when files change on disk (e.g.
/// after the AI edits them).
@MainActor
final class DataStore: ObservableObject {
    @Published var todos: [TodoItem] = []
    @Published var categories: [TodoCategory] = []
    @Published var sessions: [PomodoroSession] = []
    @Published var loadError: String?

    private var watcher: FileWatcher?
    private var suppressReloadUntil = Date.distantPast

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init() {
        Paths.ensureDirectories()
        WorkspacePrimer.primeIfNeeded()
        seedIfFirstLaunch()
        reloadFromDisk()
        watcher = FileWatcher(url: Paths.dataDir) { [weak self] in
            self?.reloadIfExternalChange()
        }
    }

    // MARK: - Loading

    func reloadFromDisk() {
        loadError = nil
        todos = load(TodosFile.self, from: Paths.todosFile)?.todos ?? todos
        categories = (load(CategoriesFile.self, from: Paths.categoriesFile)?.categories ?? categories)
            .sorted { $0.sortOrder < $1.sortOrder }
        sessions = load(SessionsFile.self, from: Paths.sessionsFile)?.sessions ?? sessions
    }

    private func reloadIfExternalChange() {
        // Skip reloads triggered by our own recent writes.
        guard Date() > suppressReloadUntil else { return }
        reloadFromDisk()
    }

    private func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try Self.decoder.decode(T.self, from: data)
        } catch {
            loadError = "Failed to parse \(url.lastPathComponent): \(error.localizedDescription)"
            return nil
        }
    }

    // MARK: - Saving

    private func save<T: Encodable>(_ value: T, to url: URL) {
        do {
            let data = try Self.encoder.encode(value)
            suppressReloadUntil = Date().addingTimeInterval(1.0)
            try data.write(to: url, options: .atomic)
        } catch {
            loadError = "Failed to save \(url.lastPathComponent): \(error.localizedDescription)"
        }
    }

    private func saveTodos() { save(TodosFile(todos: todos), to: Paths.todosFile) }
    private func saveCategories() { save(CategoriesFile(categories: categories), to: Paths.categoriesFile) }
    private func saveSessions() { save(SessionsFile(sessions: sessions), to: Paths.sessionsFile) }

    // MARK: - Todo CRUD

    func addTodo(_ todo: TodoItem) {
        todos.insert(todo, at: 0)
        saveTodos()
    }

    func updateTodo(_ todo: TodoItem) {
        guard let i = todos.firstIndex(where: { $0.id == todo.id }) else { return }
        todos[i] = todo
        saveTodos()
    }

    func toggleComplete(_ todo: TodoItem) {
        guard let i = todos.firstIndex(where: { $0.id == todo.id }) else { return }
        todos[i].isCompleted.toggle()
        todos[i].completedAt = todos[i].isCompleted ? Date() : nil
        saveTodos()
    }

    func deleteTodo(_ todo: TodoItem) {
        todos.removeAll { $0.id == todo.id }
        saveTodos()
    }

    // MARK: - Category CRUD

    func addCategory(name: String, colorHex: String = "#4A90D9", icon: String = "folder") {
        let maxOrder = categories.map(\.sortOrder).max() ?? -1
        categories.append(TodoCategory(name: name, colorHex: colorHex, icon: icon, sortOrder: maxOrder + 1))
        saveCategories()
    }

    func renameCategory(_ category: TodoCategory, to name: String) {
        guard let i = categories.firstIndex(where: { $0.id == category.id }) else { return }
        categories[i].name = name
        saveCategories()
    }

    func deleteCategory(_ category: TodoCategory) {
        categories.removeAll { $0.id == category.id }
        for i in todos.indices where todos[i].categoryId == category.id {
            todos[i].categoryId = nil
        }
        saveCategories()
        saveTodos()
    }

    func category(for todo: TodoItem) -> TodoCategory? {
        guard let id = todo.categoryId else { return nil }
        return categories.first { $0.id == id }
    }

    // MARK: - Pomodoro sessions

    func recordSession(_ session: PomodoroSession) {
        sessions.append(session)
        saveSessions()
    }

    // MARK: - Stats

    var todayCompletedWorkSessions: Int {
        sessions.filter {
            $0.kind == .work && $0.completed && Calendar.current.isDateInToday($0.endedAt)
        }.count
    }

    var todayFocusMinutes: Int {
        let secs = sessions
            .filter { $0.kind == .work && Calendar.current.isDateInToday($0.endedAt) }
            .reduce(0.0) { $0 + $1.endedAt.timeIntervalSince($1.startedAt) }
        return Int(secs / 60)
    }

    // MARK: - First launch seed

    private func seedIfFirstLaunch() {
        guard !FileManager.default.fileExists(atPath: Paths.todosFile.path) else { return }
        categories = [
            TodoCategory(name: "Work", colorHex: "#E06C4F", icon: "briefcase", sortOrder: 0),
            TodoCategory(name: "Personal", colorHex: "#4A90D9", icon: "person", sortOrder: 1),
            TodoCategory(name: "Learning", colorHex: "#5CA65C", icon: "book", sortOrder: 2),
        ]
        saveCategories()
        saveTodos()
        saveSessions()
    }
}
