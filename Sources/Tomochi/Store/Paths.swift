import Foundation

/// All on-disk locations. The "workspace" is the AI-operable directory:
/// every piece of app data lives there as human-readable JSON/Markdown so
/// that `claude -p` / `codex exec` can read and edit it directly.
enum Paths {
    static var workspace: URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0]
        return base.appendingPathComponent("Tomochi/workspace", isDirectory: true)
    }

    static var dataDir: URL { workspace.appendingPathComponent("data", isDirectory: true) }
    static var memoryDir: URL { workspace.appendingPathComponent("memory", isDirectory: true) }
    static var notesDir: URL { workspace.appendingPathComponent("notes", isDirectory: true) }
    static var attachmentsDir: URL { workspace.appendingPathComponent("attachments", isDirectory: true) }

    static var todosFile: URL { dataDir.appendingPathComponent("todos.json") }
    static var categoriesFile: URL { dataDir.appendingPathComponent("categories.json") }
    static var sessionsFile: URL { dataDir.appendingPathComponent("sessions.json") }
    static var memoryFile: URL { memoryDir.appendingPathComponent("MEMORY.md") }
    static var claudeMd: URL { workspace.appendingPathComponent("CLAUDE.md") }
    static var agentsMd: URL { workspace.appendingPathComponent("AGENTS.md") }

    static func ensureDirectories() {
        let fm = FileManager.default
        for dir in [workspace, dataDir, memoryDir, notesDir, attachmentsDir] {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
}
