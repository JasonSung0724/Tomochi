import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var store: DataStore
    @Binding var selection: SidebarItem?

    @State private var newCategoryName = ""
    @State private var isAddingCategory = false
    @State private var renamingCategory: TodoCategory?
    @State private var renameText = ""
    @FocusState private var addFieldFocused: Bool

    var body: some View {
        List(selection: $selection) {
            Section("Lists") {
                Label("All", systemImage: "tray.full")
                    .tag(SidebarItem.all)
                    .badge(store.todos.filter { !$0.isCompleted }.count)
                Label("Today", systemImage: "star")
                    .tag(SidebarItem.today)
                    .badge(todayCount)
                Label("Completed", systemImage: "checkmark.circle")
                    .tag(SidebarItem.completed)
                Label("Notes", systemImage: "note.text")
                    .tag(SidebarItem.notes)
            }
            Section("Categories") {
                ForEach(store.categories) { category in
                    Label {
                        Text(category.name)
                    } icon: {
                        Image(systemName: category.icon)
                            .foregroundStyle(category.color)
                    }
                    .tag(SidebarItem.category(category.id))
                    .badge(count(for: category))
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
                        .focused($addFieldFocused)
                        .onSubmit { commitNewCategory() }
                        .onExitCommand { cancelNewCategory() }
                        .onChange(of: addFieldFocused) {
                            if !addFieldFocused { cancelNewCategory() }
                        }
                } else {
                    Button {
                        isAddingCategory = true
                        addFieldFocused = true
                    } label: {
                        Label("New Category", systemImage: "plus")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.sidebar)
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
