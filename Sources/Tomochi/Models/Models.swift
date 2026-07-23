import Foundation
import SwiftUI

// MARK: - Priority

enum Priority: String, Codable, CaseIterable, Identifiable {
    case low, normal, high

    var id: String { rawValue }

    var label: String {
        switch self {
        case .low: return "Low"
        case .normal: return "Medium"
        case .high: return "High"
        }
    }

    var color: Color {
        switch self {
        case .low: return Theme.priorityLow
        case .normal: return Theme.priorityNormal
        case .high: return Theme.priorityHigh
        }
    }
}

// MARK: - TodoItem

struct TodoItem: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    var title: String
    var notes: String
    var categoryId: UUID?
    var priority: Priority
    var dueDate: Date?
    var isCompleted: Bool
    var createdAt: Date
    var completedAt: Date?
    var tags: [String]

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        categoryId: UUID? = nil,
        priority: Priority = .normal,
        dueDate: Date? = nil,
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.categoryId = categoryId
        self.priority = priority
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.tags = tags
    }

    // Tolerant decoding so hand-edited or AI-edited JSON with missing
    // optional fields still loads.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        categoryId = try c.decodeIfPresent(UUID.self, forKey: .categoryId)
        priority = try c.decodeIfPresent(Priority.self, forKey: .priority) ?? .normal
        dueDate = try c.decodeIfPresent(Date.self, forKey: .dueDate)
        isCompleted = try c.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
    }
}

// MARK: - Category

struct TodoCategory: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    var name: String
    var colorHex: String
    var icon: String
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String = "#4A90D9",
        icon: String = "folder",
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.icon = icon
        self.sortOrder = sortOrder
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Untitled"
        colorHex = try c.decodeIfPresent(String.self, forKey: .colorHex) ?? "#4A90D9"
        icon = try c.decodeIfPresent(String.self, forKey: .icon) ?? "folder"
        sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
    }

    var color: Color { Color(hex: colorHex) ?? .accentColor }
}

// MARK: - PomodoroSession

struct PomodoroSession: Codable, Identifiable, Equatable {
    enum Kind: String, Codable {
        case work, shortBreak, longBreak
    }

    var id: UUID
    var todoId: UUID?
    var kind: Kind
    var startedAt: Date
    var endedAt: Date
    var completed: Bool

    init(
        id: UUID = UUID(),
        todoId: UUID? = nil,
        kind: Kind = .work,
        startedAt: Date,
        endedAt: Date,
        completed: Bool
    ) {
        self.id = id
        self.todoId = todoId
        self.kind = kind
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.completed = completed
    }
}

// MARK: - File wrappers (top-level JSON documents on disk)

struct TodosFile: Codable, Equatable {
    var version: Int = 1
    var todos: [TodoItem] = []
}

struct CategoriesFile: Codable, Equatable {
    var version: Int = 1
    var categories: [TodoCategory] = []
}

struct SessionsFile: Codable, Equatable {
    var version: Int = 1
    var sessions: [PomodoroSession] = []
}

// MARK: - Color helpers

extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt64(s, radix: 16) else { return nil }
        self.init(
            red: Double((v >> 16) & 0xFF) / 255,
            green: Double((v >> 8) & 0xFF) / 255,
            blue: Double(v & 0xFF) / 255
        )
    }
}
