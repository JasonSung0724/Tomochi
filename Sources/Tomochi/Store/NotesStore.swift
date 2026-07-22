import Foundation
import Combine

struct Note: Identifiable, Equatable {
    let filename: String
    var title: String
    var modifiedAt: Date

    var id: String { filename }
}

/// Markdown notes in the AI workspace (`notes/*.md`), one file per note.
/// The AI writes here too, so the list live-reloads on directory changes.
@MainActor
final class NotesStore: ObservableObject {
    @Published var notes: [Note] = []

    private var watcher: FileWatcher?
    private var suppressReloadUntil = Date.distantPast

    init() {
        refresh()
        watcher = FileWatcher(url: Paths.notesDir) { [weak self] in
            guard let self, Date() > self.suppressReloadUntil else { return }
            self.refresh()
        }
    }

    func refresh() {
        let fm = FileManager.default
        let urls = (try? fm.contentsOfDirectory(
            at: Paths.notesDir, includingPropertiesForKeys: [.contentModificationDateKey]
        )) ?? []
        notes = urls
            .filter { $0.pathExtension.lowercased() == "md" }
            .map { url in
                let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey])
                    .contentModificationDate) ?? .distantPast
                return Note(
                    filename: url.lastPathComponent,
                    title: Self.title(of: url),
                    modifiedAt: modified
                )
            }
            .sorted { $0.modifiedAt > $1.modifiedAt }
    }

    /// First markdown heading, else first non-empty line, else the filename.
    private static func title(of url: URL) -> String {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return url.deletingPathExtension().lastPathComponent
        }
        for line in content.split(separator: "\n", omittingEmptySubsequences: true) {
            let text = line.trimmingCharacters(in: CharacterSet(charactersIn: "# ").union(.whitespaces))
            if !text.isEmpty { return text }
        }
        return url.deletingPathExtension().lastPathComponent
    }

    func content(of note: Note) -> String {
        (try? String(contentsOf: Paths.notesDir.appendingPathComponent(note.filename),
                     encoding: .utf8)) ?? ""
    }

    func save(filename: String, content: String) {
        suppressReloadUntil = Date().addingTimeInterval(1.0)
        try? content.data(using: .utf8)?
            .write(to: Paths.notesDir.appendingPathComponent(filename), options: .atomic)
        if let i = notes.firstIndex(where: { $0.filename == filename }) {
            notes[i].modifiedAt = Date()
            let url = Paths.notesDir.appendingPathComponent(filename)
            notes[i].title = Self.title(of: url)
        }
    }

    func create() -> Note {
        let fm = FileManager.default
        var filename = "untitled.md"
        var n = 2
        while fm.fileExists(atPath: Paths.notesDir.appendingPathComponent(filename).path) {
            filename = "untitled-\(n).md"
            n += 1
        }
        save(filename: filename, content: "# New note\n\n")
        let note = Note(filename: filename, title: "New note", modifiedAt: Date())
        notes.insert(note, at: 0)
        return note
    }

    func delete(_ note: Note) {
        suppressReloadUntil = Date().addingTimeInterval(1.0)
        try? FileManager.default.removeItem(
            at: Paths.notesDir.appendingPathComponent(note.filename))
        notes.removeAll { $0.filename == note.filename }
    }

    /// Copies a file into attachments/ (deduplicating names) and returns the
    /// markdown link to insert into a note.
    func importAttachment(from url: URL) -> String? {
        let fm = FileManager.default
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        var name = url.lastPathComponent
        var n = 2
        while fm.fileExists(atPath: Paths.attachmentsDir.appendingPathComponent(name).path) {
            name = "\(base)-\(n).\(ext)"
            n += 1
        }
        do {
            try fm.copyItem(at: url, to: Paths.attachmentsDir.appendingPathComponent(name))
        } catch {
            return nil
        }
        return "![\(base)](../attachments/\(name))"
    }
}
