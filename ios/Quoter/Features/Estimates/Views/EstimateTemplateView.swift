import SwiftUI
import UIKit

private func scopeLocalized(_ key: String) -> String {
    AppLanguage.localizedString(key)
}

private func scopeDisplayName(_ value: String) -> String {
    if value == "Other" {
        return AppLanguage.localizedString("Other Category")
    }
    return AppLanguage.localizedKnownSystemString(value)
}

struct EstimateTemplateView: View {
    let project: Project

    var body: some View {
        QuoteScopeBuilderView(project: project)
    }
}

struct QuoteScopeBuilderView: View {
    @EnvironmentObject private var appState: AppState
    let project: Project
    @StateObject private var viewModel: QuoteScopeBuilderViewModel
    @State private var newCategoryName = ""
    @State private var showingNewCategory = false
    @State private var templateName = ""
    @State private var showingSaveTemplate = false
    @State private var renamingCategory: EstimateCategory?
    @State private var categoryName = ""

    init(project: Project) {
        self.project = project
        _viewModel = StateObject(wrappedValue: QuoteScopeBuilderViewModel(projectID: project.id))
    }

    var body: some View {
        Group {
            if let estimateBinding {
                scopeEditor(estimate: estimateBinding)
            } else {
                renovationTypePicker
            }
        }
        .navigationTitle("Quote Scope Builder")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if viewModel.estimate != nil {
                    Button {
                        Task { await viewModel.saveCurrentEstimate() }
                    } label: {
                        Label(scopeLocalized(viewModel.isSaving ? "Saving" : "Save Scope"), systemImage: "square.and.arrow.down")
                    }
                    .disabled(viewModel.isSaving)

                    Menu {
                        Button {
                            Task { await viewModel.importDrawingItems() }
                        } label: {
                            Label("Import from Drawing", systemImage: "arrow.down.doc")
                        }

                        Button {
                            showingSaveTemplate = true
                        } label: {
                            Label("Save Template", systemImage: "tray.and.arrow.down")
                        }

                        Button {
                            showingNewCategory = true
                        } label: {
                            Label("Add Category", systemImage: "folder.badge.plus")
                        }

                        Button {
                            viewModel.clearCurrentEstimate()
                        } label: {
                            Label("Change Type", systemImage: "rectangle.2.swap")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            QuoteScopeStatusBar(
                selectedCount: viewModel.selectedItemCount,
                warningCount: viewModel.warningCount,
                isSaving: viewModel.isSaving,
                message: viewModel.statusMessage ?? viewModel.errorMessage
            )
        }
        .alert("Add Category", isPresented: $showingNewCategory) {
            TextField("Category name", text: $newCategoryName)
            Button("Cancel", role: .cancel) {
                newCategoryName = ""
            }
            Button("Add") {
                viewModel.addCategory(named: newCategoryName)
                newCategoryName = ""
            }
        }
        .alert("Rename Category", isPresented: Binding(
            get: { renamingCategory != nil },
            set: { isPresented in
                if !isPresented {
                    renamingCategory = nil
                    categoryName = ""
                }
            }
        )) {
            TextField("Category name", text: $categoryName)
            Button("Cancel", role: .cancel) {
                renamingCategory = nil
                categoryName = ""
            }
            Button("Save") {
                if let renamingCategory {
                    viewModel.renameCategory(renamingCategory, to: categoryName)
                }
                renamingCategory = nil
                categoryName = ""
            }
        }
        .alert("Save Current Estimate as Template", isPresented: $showingSaveTemplate) {
            TextField(scopeLocalized("Template name"), text: $templateName)
            Button("Cancel", role: .cancel) {
                templateName = ""
            }
            Button("Save") {
                Task {
                    await viewModel.saveReusableTemplate(named: templateName.isEmpty ? project.title : templateName)
                }
                templateName = ""
            }
        } message: {
            Text("This saves the scope structure without pricing for future projects.")
        }
        .task {
            viewModel.configure(apiClient: appState.apiClient)
            await viewModel.load()
        }
    }

    private var estimateBinding: Binding<EstimateTemplate>? {
        guard viewModel.estimate != nil else { return nil }
        return Binding {
            viewModel.estimate ?? EstimateTemplate.makeDefault(projectID: project.id, type: .customProject)
        } set: { updated in
            viewModel.replaceEstimate(updated)
        }
    }

    private var renovationTypePicker: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(project.title)
                        .font(.headline)
                    Text("Choose the scope structure. The field team records rooms, materials, quantities, and notes only; pricing stays pending for office review.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            if !viewModel.reusableTemplates.isEmpty {
                Section("Create from Saved Template") {
                    ForEach(viewModel.reusableTemplates) { template in
                        Button {
                            Task { await viewModel.applyReusableTemplate(template) }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: template.renovationType.systemImage)
                                    .foregroundStyle(.blue)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(template.name)
                                        .font(.body.weight(.medium))
                                    Text(template.renovationType.localizedShortTitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            Section("Renovation Type") {
                ForEach(RenovationType.allCases) { type in
                    Button {
                        viewModel.createEstimate(type: type, name: type.localizedTitle)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: type.systemImage)
                                .frame(width: 28)
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(type.localizedTitle)
                                    .font(.body.weight(.medium))
                                Text(String(format: scopeLocalized("%d categories"), QuoteScopeCatalog.categories(for: type).count))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func scopeEditor(estimate: Binding<EstimateTemplate>) -> some View {
        List {
            Section {
                TextField("Search item or category", text: $viewModel.searchText)
                    .textInputAutocapitalization(.never)

                Toggle("Hide unselected items", isOn: $viewModel.hideUnselectedItems)

                HStack {
                    Label("Pricing pending", systemImage: "clock.badge.exclamationmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.orange)
                    Spacer()
                    Text("\(viewModel.selectedItemCount) selected")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                HStack {
                    Label(estimate.wrappedValue.renovationType.localizedTitle, systemImage: estimate.wrappedValue.renovationType.systemImage)
                    Spacer()
                    Text("No field pricing")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(estimate.categories) { category in
                if viewModel.shouldShowCategory(category.wrappedValue) {
                    ScopeCategoryDisclosure(
                        category: category,
                        isExpanded: viewModel.isExpanded(category.wrappedValue),
                        hideUnselectedItems: viewModel.hideUnselectedItems,
                        searchText: viewModel.searchText,
                        onToggleExpanded: {
                            viewModel.toggleExpanded(category.wrappedValue)
                        },
                        onAddItem: {
                            viewModel.addItem(to: category.wrappedValue)
                        },
                        onRenameCategory: {
                            categoryName = scopeDisplayName(category.wrappedValue.name)
                            renamingCategory = category.wrappedValue
                        },
                        onDeleteCategory: {
                            viewModel.deleteCategory(category.wrappedValue)
                        },
                        onDuplicateItem: { item in
                            viewModel.duplicateItem(item, in: category.wrappedValue)
                        },
                        onDeleteItem: { item in
                            viewModel.deleteItem(item, in: category.wrappedValue)
                        },
                        onChanged: {
                            viewModel.markChanged()
                        }
                    )
                }
            }
        }
    }
}

private struct ScopeCategoryDisclosure: View {
    @Binding var category: EstimateCategory
    let isExpanded: Bool
    let hideUnselectedItems: Bool
    let searchText: String
    let onToggleExpanded: () -> Void
    let onAddItem: () -> Void
    let onRenameCategory: () -> Void
    let onDeleteCategory: () -> Void
    let onDuplicateItem: (EstimateItem) -> Void
    let onDeleteItem: (EstimateItem) -> Void
    let onChanged: () -> Void

    var body: some View {
        Section {
            HStack(spacing: 10) {
                Button {
                    onToggleExpanded()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: isExpanded ? "chevron.down.circle.fill" : "chevron.right.circle")
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(scopeDisplayName(category.name))
                                .font(.headline)
                            Text("\(selectedItems.count) selected / \(category.items.count) items")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.plain)

                Button {
                    onAddItem()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)

                Menu {
                    Button {
                        onRenameCategory()
                    } label: {
                        Label("Rename Category", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        onDeleteCategory()
                    } label: {
                        Label("Delete Category", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }

            if isExpanded {
                if visibleItems.isEmpty {
                    ContentUnavailableView("No scope items", systemImage: "checklist")
                        .frame(minHeight: 120)
                } else {
                    ForEach($category.items) { $item in
                        if shouldShowItem(item) {
                            ScopeItemCard(
                                item: $item,
                                onDuplicate: { onDuplicateItem(item) },
                                onDelete: { onDeleteItem(item) },
                                onChanged: onChanged
                            )
                        }
                    }
                }

                Button {
                    onAddItem()
                } label: {
                    Label("Add Item", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var selectedItems: [EstimateItem] {
        category.items.filter(\.selected)
    }

    private var visibleItems: [EstimateItem] {
        category.items.filter(shouldShowItem)
    }

    private func shouldShowItem(_ item: EstimateItem) -> Bool {
        if hideUnselectedItems && !item.selected {
            return false
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return category.name.localizedCaseInsensitiveContains(query)
            || item.itemName.localizedCaseInsensitiveContains(query)
            || item.roomName.localizedCaseInsensitiveContains(query)
            || item.roomType.localizedCaseInsensitiveContains(query)
            || item.materialChoice.localizedCaseInsensitiveContains(query)
            || item.notes.localizedCaseInsensitiveContains(query)
    }
}

private struct ScopeItemCard: View {
    @Binding var item: EstimateItem
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    let onChanged: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Button {
                    item.selected.toggle()
                    onChanged()
                } label: {
                    Image(systemName: item.selected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(item.selected ? .blue : .secondary)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 5) {
                    TextField("Scope item", text: $item.itemName)
                        .font(.headline)
                        .onSubmit(onChanged)
                    if !item.scopeCode.isEmpty {
                        Text(item.scopeCode.replacingOccurrences(of: "_", with: " "))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text("Pending")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.12), in: Capsule())

                Menu {
                    Button {
                        onDuplicate()
                    } label: {
                        Label("Copy Item", systemImage: "doc.on.doc")
                    }
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete Item", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                TextEntryField(title: "Room Name", text: $item.roomName, onCommit: onChanged)
                PickerEntryField(title: "Room Type", selection: $item.roomType, options: QuoteScopeCatalog.roomTypes, onChange: onChanged)
                PickerEntryField(title: "Floor Level", selection: $item.floorLevel, options: QuoteScopeCatalog.floorLevels, onChange: onChanged)
                DecimalEntryField(title: "Quantity", value: $item.quantity, keyboardType: .decimalPad, onCommit: onChanged)
                PickerEntryField(title: "Unit", selection: $item.unit, options: UnitType.allCases.map(\.rawValue), onChange: onChanged)
                PickerEntryField(title: "Supplied By", selection: $item.suppliedBy, options: QuoteScopeCatalog.suppliedByOptions, onChange: onChanged)
            }

            if !materialOptions.isEmpty {
                Picker("Material / Spec", selection: $item.materialChoice) {
                    Text("TBD").tag("")
                    ForEach(materialOptions, id: \.self) { option in
                        Text(AppLanguage.localizedKnownSystemString(option)).tag(option)
                    }
                }
                .onChange(of: item.materialChoice) { _, _ in onChanged() }
            }

            TextField("Material / Spec Notes", text: $item.materialChoice, axis: .vertical)
                .lineLimit(1...3)
                .textFieldStyle(.roundedBorder)
                .onSubmit(onChanged)

            TextField("Notes", text: $item.notes, axis: .vertical)
                .lineLimit(2...5)
                .textFieldStyle(.roundedBorder)
                .onSubmit(onChanged)

            if !item.riskFlags.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(item.riskFlags, id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .onChange(of: item.selected) { _, _ in onChanged() }
    }

    private var materialOptions: [String] {
        QuoteScopeCatalog.materialOptions(for: item.scopeCode)
    }
}

private struct PickerEntryField: View {
    let title: String
    @Binding var selection: String
    let options: [String]
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(scopeLocalized(title))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Picker(scopeLocalized(title), selection: $selection) {
                Text("TBD").tag("")
                ForEach(options, id: \.self) { option in
                    Text(AppLanguage.localizedKnownSystemString(option)).tag(option)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selection) { _, _ in onChange() }
        }
    }
}

private struct DecimalEntryField: View {
    let title: String
    @Binding var value: Decimal
    let keyboardType: UIKeyboardType
    let onCommit: () -> Void
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(scopeLocalized(title))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(scopeLocalized("0"), text: $text)
                .keyboardType(keyboardType)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onChange(of: text) { _, newValue in
                    let parsed = Decimal(string: newValue) ?? 0
                    value = Swift.max(parsed, Decimal(0))
                }
                .onChange(of: isFocused) { _, focused in
                    if !focused {
                        text = Self.displayString(value)
                        onCommit()
                    }
                }
                .onAppear {
                    text = Self.displayString(value)
                }
                .onChange(of: value) { _, newValue in
                    if !isFocused {
                        text = Self.displayString(newValue)
                    }
                }
        }
    }

    private static func displayString(_ value: Decimal) -> String {
        if value == 0 { return "" }
        return NSDecimalNumber(decimal: value).stringValue
    }
}

private struct TextEntryField: View {
    let title: String
    @Binding var text: String
    let onCommit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(scopeLocalized(title))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(scopeLocalized(title), text: $text)
                .textFieldStyle(.roundedBorder)
                .onSubmit(onCommit)
        }
    }
}

private struct QuoteScopeStatusBar: View {
    let selectedCount: Int
    let warningCount: Int
    let isSaving: Bool
    let message: String?

    var body: some View {
        HStack(spacing: 12) {
            Label("\(selectedCount) scope items", systemImage: "checklist")
            if warningCount > 0 {
                Label("\(warningCount) warnings", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
            Spacer()
            if isSaving {
                ProgressView()
            }
            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(message.localizedCaseInsensitiveContains("failed") ? .red : .secondary)
                    .lineLimit(1)
            } else {
                Text("Pricing pending")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.footnote)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }
}

@MainActor
final class QuoteScopeBuilderViewModel: ObservableObject {
    @Published var estimate: EstimateTemplate?
    @Published private(set) var reusableTemplates: [EstimateTemplate] = []
    @Published var searchText = ""
    @Published var hideUnselectedItems = false
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?
    @Published var statusMessage: String?
    @Published private(set) var hasUnsavedChanges = false

    private let projectID: UUID
    private let store = EstimateStore()
    private var service: EstimateTemplateService?
    private var expandedCategoryIDs: Set<UUID> = []

    init(projectID: UUID) {
        self.projectID = projectID
    }

    var selectedItemCount: Int {
        estimate?.categories.flatMap(\.items).filter(\.selected).count ?? 0
    }

    var warningCount: Int {
        estimate?.categories.flatMap(\.items).flatMap(\.riskFlags).count ?? 0
    }

    func configure(apiClient: APIClient) {
        if service == nil {
            service = EstimateTemplateService(apiClient: apiClient)
        }
    }

    func load() async {
        do {
            if let service {
                let loaded = try await service.getProjectEstimate(projectID: projectID)
                if loaded.categories.isEmpty {
                    estimate = nil
                    expandedCategoryIDs = []
                } else {
                    estimate = loaded
                    expandedCategoryIDs = Set(loaded.categories.prefix(4).map(\.id))
                }
                reusableTemplates = try await service.listTemplates()
            } else {
                estimate = try store.loadProjectEstimate(projectID: projectID)
                reusableTemplates = try store.loadReusableTemplates()
            }
            errorMessage = nil
        } catch {
            do {
                estimate = try store.loadProjectEstimate(projectID: projectID)
                reusableTemplates = try store.loadReusableTemplates()
            } catch {
                // Keep the API error as the visible message.
            }
            errorMessage = AppLanguage.localizedErrorDescription(error)
        }
    }

    func createEstimate(type: RenovationType, name: String) {
        let newEstimate = EstimateTemplate.makeDefault(projectID: projectID, type: type, name: name)
        estimate = newEstimate
        expandedCategoryIDs = Set(newEstimate.categories.prefix(4).map(\.id))
        Task { await saveCurrentEstimate() }
    }

    func applyReusableTemplate(_ template: EstimateTemplate) async {
        do {
            if let service {
                let applied = try await service.applyTemplate(projectID: projectID, templateID: template.id)
                estimate = applied
                expandedCategoryIDs = Set(applied.categories.prefix(4).map(\.id))
            } else {
                let copy = template.projectCopy(projectID: projectID, named: template.name)
                estimate = copy
                expandedCategoryIDs = Set(copy.categories.prefix(4).map(\.id))
                try store.saveProjectEstimate(copy, projectID: projectID)
            }
            errorMessage = nil
        } catch {
            errorMessage = AppLanguage.localizedErrorDescription(error)
        }
    }

    func importDrawingItems() async {
        do {
            if let service {
                let imported = try await service.importDrawingItems(projectID: projectID)
                estimate = imported
                expandedCategoryIDs = Set(imported.categories.map(\.id))
                showStatus("Drawing items imported")
            }
            errorMessage = nil
        } catch {
            errorMessage = AppLanguage.localizedErrorDescription(error)
        }
    }

    func clearCurrentEstimate() {
        estimate = nil
        expandedCategoryIDs = []
        do {
            try store.deleteProjectEstimate(projectID: projectID)
            errorMessage = nil
        } catch {
            errorMessage = AppLanguage.localizedErrorDescription(error)
        }
    }

    func replaceEstimate(_ updated: EstimateTemplate) {
        estimate = sanitize(updated)
        markUnsaved()
    }

    func markChanged() {
        guard let estimate else { return }
        self.estimate = sanitize(estimate)
        markUnsaved()
    }

    func saveCurrentEstimate() async {
        guard let estimate else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let sanitized = sanitize(estimate)
            if let service {
                let saved = try await service.saveProjectEstimate(sanitized, projectID: projectID)
                self.estimate = saved
            } else {
                try store.saveProjectEstimate(sanitized, projectID: projectID)
                self.estimate = sanitized
            }
            showStatus("Scope saved")
            hasUnsavedChanges = false
            errorMessage = nil
        } catch {
            errorMessage = AppLanguage.localizedErrorDescription(error)
        }
    }

    func saveReusableTemplate(named rawName: String) async {
        guard let estimate else { return }
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let sanitized = sanitize(estimate)
            if let service {
                let saved = try await service.saveTemplate(sanitized, name: name, projectID: projectID)
                reusableTemplates.removeAll { $0.id == saved.id || $0.name.caseInsensitiveCompare(saved.name) == .orderedSame }
                reusableTemplates.insert(saved, at: 0)
            } else {
                try store.saveReusableTemplate(sanitized, name: name)
                reusableTemplates = try store.loadReusableTemplates()
            }
            showStatus("Template saved")
            errorMessage = nil
        } catch {
            errorMessage = AppLanguage.localizedErrorDescription(error)
        }
    }

    func addCategory(named rawName: String) {
        guard var estimate else { return }
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let category = EstimateCategory(name: name, sortOrder: estimate.categories.count)
        estimate.categories.append(category)
        self.estimate = estimate
        expandedCategoryIDs.insert(category.id)
        markUnsaved()
    }

    func renameCategory(_ category: EstimateCategory, to rawName: String) {
        guard var estimate,
              let categoryIndex = estimate.categories.firstIndex(where: { $0.id == category.id }) else { return }
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        estimate.categories[categoryIndex].name = name
        self.estimate = estimate
        markUnsaved()
    }

    func deleteCategory(_ category: EstimateCategory) {
        guard var estimate else { return }
        estimate.categories.removeAll { $0.id == category.id }
        expandedCategoryIDs.remove(category.id)
        self.estimate = estimate
        markUnsaved()
    }

    func addItem(to category: EstimateCategory) {
        guard var estimate,
              let categoryIndex = estimate.categories.firstIndex(where: { $0.id == category.id }) else { return }
        let item = EstimateItem(
            itemName: "Custom Scope Item",
            categoryID: category.id,
            scopeCode: "custom_scope_item",
            suppliedBy: "TBD",
            pricingStatus: "pending",
            unit: UnitType.allowance.rawValue,
            selected: true
        )
        estimate.categories[categoryIndex].items.append(item)
        self.estimate = estimate
        expandedCategoryIDs.insert(category.id)
        markUnsaved()
    }

    func duplicateItem(_ item: EstimateItem, in category: EstimateCategory) {
        guard var estimate,
              let categoryIndex = estimate.categories.firstIndex(where: { $0.id == category.id }) else { return }
        var copy = item
        copy.id = UUID()
        copy.itemName = item.itemName.isEmpty ? "Copy" : "\(item.itemName) Copy"
        estimate.categories[categoryIndex].items.append(copy)
        self.estimate = estimate
        markUnsaved()
    }

    func deleteItem(_ item: EstimateItem, in category: EstimateCategory) {
        guard var estimate,
              let categoryIndex = estimate.categories.firstIndex(where: { $0.id == category.id }) else { return }
        estimate.categories[categoryIndex].items.removeAll { $0.id == item.id }
        self.estimate = estimate
        markUnsaved()
    }

    func shouldShowCategory(_ category: EstimateCategory) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if hideUnselectedItems && category.items.allSatisfy({ !$0.selected }) && !category.items.isEmpty {
            return false
        }
        guard !query.isEmpty else { return true }
        return category.name.localizedCaseInsensitiveContains(query)
            || category.items.contains { item in
                item.itemName.localizedCaseInsensitiveContains(query)
                    || item.roomName.localizedCaseInsensitiveContains(query)
                    || item.roomType.localizedCaseInsensitiveContains(query)
                    || item.materialChoice.localizedCaseInsensitiveContains(query)
                    || item.notes.localizedCaseInsensitiveContains(query)
            }
    }

    func isExpanded(_ category: EstimateCategory) -> Bool {
        expandedCategoryIDs.contains(category.id)
    }

    func toggleExpanded(_ category: EstimateCategory) {
        if expandedCategoryIDs.contains(category.id) {
            expandedCategoryIDs.remove(category.id)
        } else {
            expandedCategoryIDs.insert(category.id)
        }
    }

    private func sanitize(_ estimate: EstimateTemplate) -> EstimateTemplate {
        var updated = estimate
        for categoryIndex in updated.categories.indices {
            for itemIndex in updated.categories[categoryIndex].items.indices {
                if updated.categories[categoryIndex].items[itemIndex].quantity < 0 {
                    updated.categories[categoryIndex].items[itemIndex].quantity = 0
                }
                if updated.categories[categoryIndex].items[itemIndex].suppliedBy.isEmpty {
                    updated.categories[categoryIndex].items[itemIndex].suppliedBy = "TBD"
                }
                updated.categories[categoryIndex].items[itemIndex].pricingStatus = "pending"
                updated.categories[categoryIndex].items[itemIndex].costs = .empty
                updated.categories[categoryIndex].items[itemIndex].unitPriceSnapshot = nil
            }
        }
        return updated
    }

    private func showStatus(_ message: String) {
        withAnimation {
            statusMessage = message
        }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            await MainActor.run {
                withAnimation {
                    if self?.statusMessage == message {
                        self?.statusMessage = nil
                    }
                }
            }
        }
    }

    private func markUnsaved() {
        hasUnsavedChanges = true
        statusMessage = "Unsaved changes"
    }
}
