import SwiftUI

/// Custom sidebar. Every row is a real button with the same visual language —
/// a colored icon tile — so everything that looks tappable is tappable.
/// (System List selection was swallowing clicks on some rows.)
struct SidebarView: View {
    @EnvironmentObject var store: DataStore
    @Binding var selection: SidebarItem?

    @State private var newCategoryName = ""
    @State private var isAddingCategory = false
    @State private var renamingCategory: TodoCategory?
    @State private var renameText = ""
    @FocusState private var addFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                SidebarSectionHeader(title: "Lists")
                SidebarRow(
                    title: "All", icon: "tray.fill", color: Theme.accent,
                    count: store.todos.filter { !$0.isCompleted }.count,
                    isSelected: selection == .all
                ) { selection = .all }
                SidebarRow(
                    title: "Today", icon: "star.fill", color: .orange,
                    count: todayCount,
                    isSelected: selection == .today
                ) { selection = .today }
                SidebarRow(
                    title: "Completed", icon: "checkmark", color: .green,
                    count: nil,
                    isSelected: selection == .completed
                ) { selection = .completed }
                SidebarRow(
                    title: "Notes", icon: "note.text", color: .teal,
                    count: nil,
                    isSelected: selection == .notes
                ) { selection = .notes }
                SidebarRow(
                    title: "Calendar", icon: "calendar", color: .red,
                    count: nil,
                    isSelected: selection == .calendar
                ) { selection = .calendar }

                SidebarSectionHeader(title: "Categories")
                    .padding(.top, 10)
                ForEach(store.categories) { category in
                    SidebarRow(
                        title: category.name, icon: category.icon, color: category.color,
                        count: count(for: category),
                        isSelected: selection == .category(category.id)
                    ) {
                        selection = .category(category.id)
                    }
                    .contextMenu {
                        Button("Rename") {
                            renameText = category.name
                            renamingCategory = category
                        }
                        Button("Delete", role: .destructive) {
                            store.deleteCategory(category)
                        }
                    }
                }

                if isAddingCategory {
                    TextField("Category name", text: $newCategoryName)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                        .focused($addFieldFocused)
                        .onSubmit { commitNewCategory() }
                        .onExitCommand { cancelNewCategory() }
                        .onChange(of: addFieldFocused) {
                            if !addFieldFocused { cancelNewCategory() }
                        }
                        .padding(.horizontal, 7)
                        .padding(.top, 2)
                } else {
                    SidebarRow(
                        title: "New Category", icon: "plus", color: .secondary,
                        count: nil, isSelected: false, subdued: true
                    ) {
                        isAddingCategory = true
                        addFieldFocused = true
                    }
                }
            }
            .padding(8)
        }
        .sheet(item: $renamingCategory) { category in
            VStack(spacing: 12) {
                Text("Rename Category")
                    .font(.headline)
                TextField("Name", text: $renameText)
                    .frame(width: 220)
                    .onSubmit { commitRename(category) }
                HStack {
                    Button("Cancel") { renamingCategory = nil }
                    Button("Save") { commitRename(category) }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
        }
    }

    private var todayCount: Int {
        store.todos.filter { todo in
            guard !todo.isCompleted, let due = todo.dueDate else { return false }
            return Calendar.current.isDateInToday(due) || due < Date()
        }.count
    }

    private func count(for category: TodoCategory) -> Int {
        store.todos.filter { $0.categoryId == category.id && !$0.isCompleted }.count
    }

    private func commitNewCategory() {
        let name = newCategoryName.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty {
            store.addCategory(name: name)
        }
        cancelNewCategory()
    }

    private func cancelNewCategory() {
        newCategoryName = ""
        isAddingCategory = false
    }

    private func commitRename(_ category: TodoCategory) {
        let name = renameText.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty {
            store.renameCategory(category, to: name)
        }
        renamingCategory = nil
    }
}

private struct SidebarSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(.caption, design: .rounded, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 9)
            .padding(.bottom, 3)
    }
}

private struct SidebarRow: View {
    let title: String
    let icon: String
    let color: Color
    let count: Int?
    let isSelected: Bool
    var subdued = false
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(subdued ? AnyShapeStyle(.secondary) : AnyShapeStyle(.white))
                    .frame(width: 22, height: 22)
                    .background(
                        subdued ? AnyShapeStyle(Color.primary.opacity(0.07))
                                : AnyShapeStyle(color.gradient),
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                Text(title)
                    .font(.system(.body, design: .rounded,
                                  weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(subdued ? .secondary : .primary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let count, count > 0 {
                    Text("\(count)")
                        .font(.caption.monospacedDigit().weight(.medium))
                        .foregroundStyle(isSelected ? color : .secondary)
                }
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected
                          ? color.opacity(0.16)
                          : hovering ? Color.primary.opacity(0.05) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
