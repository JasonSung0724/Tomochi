import SwiftUI
import UniformTypeIdentifiers

struct NotesView: View {
    @EnvironmentObject var notesStore: NotesStore
    @State private var selected: Note?
    @State private var content: String = ""
    @State private var saveTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 0) {
            noteList
                .frame(width: 230)
            Divider()
            editor
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            consumePendingOpen()
            if selected == nil { select(notesStore.notes.first) }
        }
        .onChange(of: notesStore.pendingOpen) { consumePendingOpen() }
        .onChange(of: notesStore.notes) {
            if let selected, !notesStore.notes.contains(where: { $0.filename == selected.filename }) {
                select(notesStore.notes.first)
            }
        }
    }

    private func consumePendingOpen() {
        guard let filename = notesStore.pendingOpen else { return }
        notesStore.pendingOpen = nil
        if let note = notesStore.notes.first(where: { $0.filename == filename }) {
            select(note)
        }
    }

    private var noteList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Notes")
                    .font(.headline)
                Spacer()
                Button {
                    select(notesStore.create())
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .buttonStyle(.plain)
                .help("New note")
            }
            .padding(10)
            Divider()
            if notesStore.notes.isEmpty {
                ContentUnavailableView("No notes", systemImage: "note.text")
                    .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(notesStore.notes) { note in
                            NoteRow(note: note, isSelected: selected?.filename == note.filename)
                                .onTapGesture { select(note) }
                                .contextMenu {
                                    Button("Delete", role: .destructive) {
                                        notesStore.delete(note)
                                    }
                                }
                        }
                    }
                    .padding(8)
                }
            }
        }
    }

    @ViewBuilder
    private var editor: some View {
        if let note = selected {
            VStack(spacing: 0) {
                HStack {
                    Text(note.filename)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        attachImage()
                    } label: {
                        Label("Attach", systemImage: "photo.badge.plus")
                    }
                    .controlSize(.small)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                Divider()
                TextEditor(text: $content)
                    .font(.system(size: 14, design: .monospaced))
                    .lineSpacing(4)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .onChange(of: content) { scheduleSave() }
                    .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                        handleDrop(providers)
                    }
            }
        } else {
            ContentUnavailableView(
                "Select or create a note",
                systemImage: "note.text",
                description: Text("Notes are Markdown files the AI can read and write too.")
            )
        }
    }

    private func select(_ note: Note?) {
        flushSave()
        selected = note
        content = note.map { notesStore.content(of: $0) } ?? ""
    }

    private func scheduleSave() {
        guard let note = selected else { return }
        saveTask?.cancel()
        let filename = note.filename
        let text = content
        saveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            notesStore.save(filename: filename, content: text)
        }
    }

    private func flushSave() {
        guard let note = selected else { return }
        saveTask?.cancel()
        notesStore.save(filename: note.filename, content: content)
    }

    private func attachImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        insertAttachment(url)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in insertAttachment(url) }
            }
            return true
        }
        return false
    }

    private func insertAttachment(_ url: URL) {
        guard let link = notesStore.importAttachment(from: url) else { return }
        if !content.hasSuffix("\n") { content += "\n" }
        content += link + "\n"
        flushSave()
    }
}

private struct NoteRow: View {
    let note: Note
    let isSelected: Bool
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(note.title)
                .font(.system(.body, design: .rounded, weight: .medium))
                .lineLimit(1)
            if !note.snippet.isEmpty {
                Text(note.snippet)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(note.modifiedAt.formatted(.dateTime.month().day().hour().minute()))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Theme.accent.opacity(0.16)
                      : hovering ? Color.primary.opacity(0.05) : .clear)
        )
        .overlay(alignment: .leading) {
            if isSelected {
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: 3)
                    .padding(.vertical, 7)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}
