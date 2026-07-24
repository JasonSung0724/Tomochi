import Foundation
import Combine

struct Note: Identifiable, Equatable {
    let filename: String
    var title: String
    var snippet: String
    var modifiedAt: Date

    var id: String { filename }
}

/// Markdown notes in the AI workspace (`notes/*.md`), one file per note.
/// The AI writes here too, so the list live-reloads on directory changes.
@MainActor
final class NotesStore: ObservableObject {
    @Published var notes: [Note] = []
    /// Set by search results to open a specific note when the Notes tab shows.
    @Published var pendingOpen: String?

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
                let (title, snippet) = Self.preview(of: url)
                return Note(
                    filename: url.lastPathComponent,
                    title: title,
                    snippet: snippet,
                    modifiedAt: modified
                )
            }
            .sorted { $0.modifiedAt > $1.modifiedAt }
    }

    /// Title = first heading/non-empty line; snippet = the next content line.
    private static func preview(of url: URL) -> (title: String, snippet: String) {
        let fallback = url.deletingPathExtension().lastPathComponent
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return (fallback, "")
        }
        let strip: (Substring) -> String = {
            $0.trimmingCharacters(in: CharacterSet(charactersIn: "#-*> ").union(.whitespaces))
        }
        let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
        var title: String?
        for line in lines {
            let text = strip(line)
            if text.isEmpty { continue }
            if title == nil {
                title = text
            } else {
                return (title ?? fallback, String(text.prefix(80)))
            }
        }
        return (title ?? fallback, "")
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
            let (title, snippet) = Self.preview(of: url)
            notes[i].title = title
            notes[i].snippet = snippet
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
        let note = Note(filename: filename, title: "New note", snippet: "", modifiedAt: Date())
        notes.insert(note, at: 0)
        return note
    }

    func delete(_ note: Note) {
        suppressReloadUntil = Date().addingTimeInterval(1.0)
        try? FileManager.default.removeItem(
            at: Paths.notesDir.appendingPathComponent(note.filename))
        notes.removeAll { $0.filename == note.filename }
    }

    /// Case-insensitive content search. Returns matching notes with a snippet
    /// of the first matching line.
    func search(_ query: String) -> [(note: Note, snippet: String)] {
        let q = query.lowercased()
        guard !q.isEmpty else { return [] }
        return notes.compactMap { note in
            let content = self.content(of: note)
            if let line = content.split(separator: "\n").first(where: { $0.lowercased().contains(q) }) {
                return (note, String(line.trimmingCharacters(in: CharacterSet(charactersIn: "# ").union(.whitespaces)).prefix(90)))
            }
            if note.title.lowercased().contains(q) {
                return (note, "")
            }
            return nil
        }
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
