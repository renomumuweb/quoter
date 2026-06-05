import SwiftUI
import UIKit

private func estimateLocalized(_ key: String) -> String {
    AppLanguage.localizedString(key)
}

private func estimateDisplayName(_ value: String) -> String {
    if value == "Other" {
        return AppLanguage.localizedString("Other Category")
    }
    AppLanguage.localizedString(value)
}

struct EstimateTemplateView: View {
    @EnvironmentObject private var appState: AppState
    let project: Project
    @StateObject private var viewModel: EstimateTemplateViewModel
    @State private var newCategoryName = ""
    @State private var showingNewCategory = false
    @State private var renamingCategory: EstimateCategory?
    @State private var categoryName = ""
    @State private var templateName = ""
    @State private var showingSaveTemplate = false
    @State private var editingItem: EstimateItemEditContext?

    init(project: Project) {
        self.project = project
        _viewModel = StateObject(wrappedValue: EstimateTemplateViewModel(projectID: project.id))
    }

    var body: some View {
        Group {
            if let estimateBinding {
                estimateEditor(estimate: estimateBinding)
            } else {
                renovationTypePicker
            }
        }
        .navigationTitle("Estimate Template")
        .toolbar {
            if viewModel.estimate != nil {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        showingSaveTemplate = true
                    } label: {
                        Label("Save Template", systemImage: "tray.and.arrow.down")
                    }
                    .disabled(viewModel.isSavingTemplate)

                    Menu {
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
            if let estimate = viewModel.estimate {
                EstimateTotalBar(
                    subtotal: estimate.subtotal,
                    tax: estimate.taxTotal,
                    total: estimate.total,
                    hiddenCount: viewModel.hiddenItemCount
                )
            }
        }
        .overlay(alignment: .bottom) {
            if let message = viewModel.statusMessage {
                Text(estimateLocalized(message))
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, viewModel.estimate == nil ? 12 : 72)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
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
            TextField(estimateLocalized("Template name"), text: $templateName)
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
            Text("This saves the category structure and any reusable items for future projects.")
        }
        .sheet(item: $editingItem) { context in
            EstimateItemEditorView(context: context, products: viewModel.products) { item in
                viewModel.saveItem(item, isNew: context.isNew)
            }
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
            viewModel.replaceEstimate(updated, shouldPersist: true)
        }
    }

    private var renovationTypePicker: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(project.title)
                        .font(.headline)
                    Text("Choose a contractor-friendly estimate structure. Categories stay broad so each site can define its own materials, labor, and subcontractor lines.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            if !viewModel.reusableTemplates.isEmpty {
                Section("Create from Saved Template") {
                    ForEach(viewModel.reusableTemplates) { template in
                        HStack {
                            Button {
                                viewModel.createFromReusableTemplate(template)
                            } label: {
                                Label(template.name, systemImage: template.renovationType.systemImage)
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Text(template.renovationType.localizedShortTitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Menu {
                                Button {
                                    viewModel.createFromReusableTemplate(template)
                                } label: {
                                    Label("Use Template", systemImage: "doc.on.clipboard")
                                }

                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.deleteReusableTemplate(template)
                                    }
                                } label: {
                                    Label("Delete Template", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundStyle(.secondary)
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
                                Text(String(format: estimateLocalized("%d categories"), type.defaultCategoryNames.count))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let message = viewModel.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.regularMaterial)
            }
        }
    }

    private func estimateEditor(estimate: Binding<EstimateTemplate>) -> some View {
        List {
            Section {
                TextField("Search item or category", text: $viewModel.searchText)
                    .textInputAutocapitalization(.never)

                Toggle("Hide unselected items", isOn: $viewModel.hideUnselectedItems)

                HStack {
                    Button {
                        showingNewCategory = true
                    } label: {
                        Label("Add Category", systemImage: "folder.badge.plus")
                    }

                    Spacer()

                    Button {
                        showingSaveTemplate = true
                    } label: {
                        Label(estimateLocalized(viewModel.isSavingTemplate ? "Saving" : "Save Template"), systemImage: "tray.and.arrow.down")
                    }
                    .disabled(viewModel.isSavingTemplate)
                }
            }

            Section {
                HStack {
                    Label(estimate.wrappedValue.renovationType.localizedTitle, systemImage: estimate.wrappedValue.renovationType.systemImage)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(DecimalFormatter.currency(estimate.wrappedValue.total))
                            .font(.headline)
                        Text("Includes HST 13%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            ForEach(estimate.categories) { category in
                if viewModel.shouldShowCategory(category.wrappedValue) {
                    EstimateCategoryDisclosure(
                        category: category,
                        isExpanded: viewModel.isExpanded(category.wrappedValue),
                        hideUnselectedItems: viewModel.hideUnselectedItems,
                        searchText: viewModel.searchText,
                        onToggleExpanded: {
                            viewModel.toggleExpanded(category.wrappedValue)
                        },
                        onAddItem: {
                            let item = EstimateItem(categoryID: category.wrappedValue.id)
                            editingItem = EstimateItemEditContext(item: item, categoryName: estimateDisplayName(category.wrappedValue.name), isNew: true)
                        },
                        onRenameCategory: {
                            categoryName = estimateDisplayName(category.wrappedValue.name)
                            renamingCategory = category.wrappedValue
                        },
                        onDeleteCategory: {
                            viewModel.deleteCategory(category.wrappedValue)
                        },
                        onEditItem: { item in
                            editingItem = EstimateItemEditContext(item: item, categoryName: estimateDisplayName(category.wrappedValue.name), isNew: false)
                        },
                        onDuplicateItem: { item in
                            viewModel.duplicateItem(item, in: category.wrappedValue)
                        },
                        onDeleteItem: { item in
                            viewModel.deleteItem(item, in: category.wrappedValue)
                        },
                        onPersist: {
                            viewModel.persistCurrentEstimate()
                        }
                    )
                }
            }
        }
    }
}

private struct EstimateCategoryDisclosure: View {
    @Binding var category: EstimateCategory
    let isExpanded: Bool
    let hideUnselectedItems: Bool
    let searchText: String
    let onToggleExpanded: () -> Void
    let onAddItem: () -> Void
    let onRenameCategory: () -> Void
    let onDeleteCategory: () -> Void
    let onEditItem: (EstimateItem) -> Void
    let onDuplicateItem: (EstimateItem) -> Void
    let onDeleteItem: (EstimateItem) -> Void
    let onPersist: () -> Void

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
                            Text(estimateDisplayName(category.name))
                                .font(.headline)
                            Text(String(format: estimateLocalized("%d items"), visibleItems.count))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(DecimalFormatter.currency(category.selectedTotal))
                            .font(.subheadline.weight(.semibold))
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
                    Button {
                        onAddItem()
                    } label: {
                        Label("Add Item", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    ForEach($category.items) { $item in
                        if shouldShowItem(item) {
                            EstimateItemCard(
                                item: $item,
                                onEdit: { onEditItem(item) },
                                onDuplicate: { onDuplicateItem(item) },
                                onDelete: { onDeleteItem(item) },
                                onPersist: onPersist
                            )
                        }
                    }
                }

                if !visibleItems.isEmpty {
                    Button {
                        onAddItem()
                    } label: {
                        Label("Add Item", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
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
        if category.name.localizedCaseInsensitiveContains(query)
            || estimateDisplayName(category.name).localizedCaseInsensitiveContains(query) {
            return true
        }
        return item.itemName.localizedCaseInsensitiveContains(query)
            || item.description.localizedCaseInsensitiveContains(query)
            || (item.skuSnapshot?.localizedCaseInsensitiveContains(query) ?? false)
            || (item.brandSnapshot?.localizedCaseInsensitiveContains(query) ?? false)
            || (item.materialSnapshot?.localizedCaseInsensitiveContains(query) ?? false)
            || item.notes.localizedCaseInsensitiveContains(query)
    }
}

private struct EstimateItemCard: View {
    @Binding var item: EstimateItem
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    let onPersist: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Button {
                    item.selected.toggle()
                    onPersist()
                } label: {
                    Image(systemName: item.selected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(item.selected ? .blue : .secondary)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    TextField(estimateLocalized("Item Name"), text: $item.itemName)
                        .font(.headline)
                        .onSubmit(onPersist)
                    if let catalogSummary = item.catalogSummary {
                        Text(catalogSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    if !item.notes.isEmpty {
                        Text(item.notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                Text(DecimalFormatter.currency(item.subtotal))
                    .font(.subheadline.weight(.semibold))
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                DecimalEntryField(title: "Qty", value: $item.quantity, keyboardType: .decimalPad, onCommit: onPersist)
                TextEntryField(title: "Unit", text: $item.unit, onCommit: onPersist)
                DecimalEntryField(title: "Material Cost", value: $item.costs.materialCost, keyboardType: .decimalPad, onCommit: onPersist)
                DecimalEntryField(title: "Labor Cost", value: $item.costs.laborCost, keyboardType: .decimalPad, onCommit: onPersist)
                DecimalEntryField(title: "Subcontractor Cost", value: $item.costs.subcontractorCost, keyboardType: .decimalPad, onCommit: onPersist)
                DecimalEntryField(title: "Other Cost", value: $item.costs.otherCost, keyboardType: .decimalPad, onCommit: onPersist)
                DecimalEntryField(title: "Markup", value: $item.costs.markup, keyboardType: .decimalPad, onCommit: onPersist)
            }

            TextEntryField(title: "Notes", text: $item.notes, onCommit: onPersist)

            HStack {
                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                Spacer()

                Button {
                    onDuplicate()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .font(.footnote.weight(.semibold))
        }
        .padding(.vertical, 6)
        .opacity(item.selected ? 1 : 0.58)
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
            Text(estimateLocalized(title))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(estimateLocalized("0"), text: $text)
                .keyboardType(keyboardType)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onChange(of: text) { _, newValue in
                    value = Decimal(string: newValue) ?? 0
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
            Text(estimateLocalized(title))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(estimateLocalized(title), text: $text)
                .textFieldStyle(.roundedBorder)
                .onSubmit(onCommit)
                .onChange(of: text) { _, _ in
                    onCommit()
                }
        }
    }
}

private struct EstimateItemEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let context: EstimateItemEditContext
    let products: [Product]
    let onSave: (EstimateItem) -> Void
    @State private var item: EstimateItem

    init(context: EstimateItemEditContext, products: [Product], onSave: @escaping (EstimateItem) -> Void) {
        self.context = context
        self.products = products
        self.onSave = onSave
        _item = State(initialValue: context.item)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Catalog Product") {
                    Picker("Product", selection: productSelection) {
                        Text("Custom Item").tag(nil as UUID?)
                        ForEach(products) { product in
                            Text(product.productPickerTitle).tag(product.id as UUID?)
                        }
                    }

                    if let catalogSummary = item.catalogSummary {
                        Label(catalogSummary, systemImage: "shippingbox")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section(context.categoryName) {
                    Toggle("Selected", isOn: $item.selected)
                    TextField(estimateLocalized("Item Name"), text: $item.itemName)
                    TextField(estimateLocalized("Description"), text: $item.description, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Quantity") {
                    DecimalEntryField(title: "Quantity", value: $item.quantity, keyboardType: .decimalPad, onCommit: {})
                    Picker("Unit", selection: $item.unit) {
                        ForEach(UnitType.allCases) { unit in
                            Text(unit.rawValue).tag(unit.rawValue)
                        }
                    }
                    TextField(estimateLocalized("Custom Unit"), text: $item.unit)
                }

                Section("Costs") {
                    DecimalEntryField(title: "Material Cost", value: $item.costs.materialCost, keyboardType: .decimalPad, onCommit: {})
                    DecimalEntryField(title: "Labor Cost", value: $item.costs.laborCost, keyboardType: .decimalPad, onCommit: {})
                    DecimalEntryField(title: "Subcontractor Cost", value: $item.costs.subcontractorCost, keyboardType: .decimalPad, onCommit: {})
                    DecimalEntryField(title: "Other Cost", value: $item.costs.otherCost, keyboardType: .decimalPad, onCommit: {})
                    DecimalEntryField(title: "Markup", value: $item.costs.markup, keyboardType: .decimalPad, onCommit: {})
                }

                Section("Notes") {
                    TextField(estimateLocalized("Notes"), text: $item.notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    HStack {
                        Text("Subtotal")
                        Spacer()
                        Text(DecimalFormatter.currency(item.subtotal))
                            .font(.headline)
                    }
                }
            }
            .navigationTitle(estimateLocalized(context.isNew ? "New Item" : "Edit Item"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(item)
                        dismiss()
                    }
                }
            }
        }
    }

    private var productSelection: Binding<UUID?> {
        Binding {
            item.productID
        } set: { productID in
            if let productID,
               let product = products.first(where: { $0.id == productID }) {
                item.apply(product: product)
            } else {
                item.clearProductLink()
            }
        }
    }
}

private extension EstimateItem {
    var catalogSummary: String? {
        guard productID != nil else { return nil }
        var parts: [String] = []
        if let skuSnapshot, !skuSnapshot.trimmedForEstimate.isEmpty {
            parts.append(skuSnapshot)
        }
        if let brandSnapshot, !brandSnapshot.trimmedForEstimate.isEmpty {
            parts.append(brandSnapshot)
        }
        if let productCategorySnapshot, !productCategorySnapshot.trimmedForEstimate.isEmpty {
            parts.append(productCategorySnapshot)
        }
        if let materialSnapshot, !materialSnapshot.trimmedForEstimate.isEmpty {
            parts.append(materialSnapshot)
        }
        if let unitPriceSnapshot {
            parts.append(DecimalFormatter.currency(unitPriceSnapshot))
        }
        return parts.isEmpty ? productNameSnapshot : parts.joined(separator: " | ")
    }

    mutating func apply(product: Product) {
        productID = product.id
        productNameSnapshot = product.name
        skuSnapshot = product.sku
        brandSnapshot = product.brand.nilIfBlankForEstimate
        productCategorySnapshot = product.category
        materialSnapshot = product.material?.nilIfBlankForEstimate
        unitPriceSnapshot = product.currentPrice
        itemName = product.name
        if let productDescription = product.description?.nilIfBlankForEstimate {
            description = productDescription
        }
        unit = product.unit.trimmedForEstimate.isEmpty ? UnitType.each.rawValue : product.unit
        if let currentPrice = product.currentPrice {
            costs.materialCost = currentPrice
        }
    }

    mutating func clearProductLink() {
        productID = nil
        productNameSnapshot = nil
        skuSnapshot = nil
        brandSnapshot = nil
        productCategorySnapshot = nil
        materialSnapshot = nil
        unitPriceSnapshot = nil
    }
}

private extension Product {
    var productPickerTitle: String {
        var details: [String] = []
        if let material, !material.trimmedForEstimate.isEmpty {
            details.append(material)
        }
        if !sku.trimmedForEstimate.isEmpty {
            details.append(sku)
        }
        if let currentPrice {
            details.append(DecimalFormatter.currency(currentPrice))
        }
        guard !details.isEmpty else { return name }
        return "\(name) (\(details.joined(separator: " | ")))"
    }
}

private extension String {
    var trimmedForEstimate: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var nilIfBlankForEstimate: String? {
        let value = trimmedForEstimate
        return value.isEmpty ? nil : value
    }
}

private struct EstimateTotalBar: View {
    let subtotal: Decimal
    let tax: Decimal
    let total: Decimal
    let hiddenCount: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    totalColumn(title: "Subtotal", value: subtotal)
                    totalColumn(title: "HST 13%", value: tax)
                }
                Text(estimateLocalized("Estimate Total"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(DecimalFormatter.currency(total))
                    .font(.title3.weight(.bold))
                if hiddenCount > 0 {
                    Label(String(format: estimateLocalized("%d hidden"), hiddenCount), systemImage: "eye.slash")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    private func totalColumn(title: String, value: Decimal) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(estimateLocalized(title))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(DecimalFormatter.currency(value))
                .font(.caption.weight(.semibold))
        }
    }
}

private struct EstimateItemEditContext: Identifiable {
    let item: EstimateItem
    let categoryName: String
    let isNew: Bool

    var id: UUID { item.id }
}

@MainActor
final class EstimateTemplateViewModel: ObservableObject {
    @Published var estimate: EstimateTemplate?
    @Published private(set) var reusableTemplates: [EstimateTemplate] = []
    @Published private(set) var products: [Product] = []
    @Published var searchText = ""
    @Published var hideUnselectedItems = false
    @Published private(set) var isSavingTemplate = false
    @Published var errorMessage: String?
    @Published var statusMessage: String?

    private let projectID: UUID
    private let store = EstimateStore()
    private var service: EstimateTemplateService?
    private var productService: ProductService?
    private var expandedCategoryIDs: Set<UUID> = []

    init(projectID: UUID) {
        self.projectID = projectID
    }

    func configure(apiClient: APIClient) {
        if service == nil {
            service = EstimateTemplateService(apiClient: apiClient)
        }
        if productService == nil {
            productService = ProductService(apiClient: apiClient)
        }
    }

    var hiddenItemCount: Int {
        guard hideUnselectedItems, let estimate else { return 0 }
        return estimate.categories.flatMap(\.items).filter { !$0.selected }.count
    }

    func load() async {
        do {
            estimate = try store.loadProjectEstimate(projectID: projectID)
            if let estimate {
                expandedCategoryIDs = Set(estimate.categories.prefix(4).map(\.id))
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        do {
            if let service, let productService {
                async let loadedTemplates = service.listTemplates()
                async let loadedProducts = productService.listProducts()
                reusableTemplates = try await loadedTemplates
                products = try await loadedProducts
            } else {
                reusableTemplates = try store.loadReusableTemplates()
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createEstimate(type: RenovationType, name: String) {
        let newEstimate = EstimateTemplate.makeDefault(projectID: projectID, type: type, name: name)
        estimate = newEstimate
        expandedCategoryIDs = Set(newEstimate.categories.prefix(4).map(\.id))
        persistCurrentEstimate()
    }

    func createFromReusableTemplate(_ template: EstimateTemplate) {
        let copy = template.projectCopy(projectID: projectID, named: template.name)
        estimate = copy
        expandedCategoryIDs = Set(copy.categories.prefix(4).map(\.id))
        persistCurrentEstimate()
    }

    func clearCurrentEstimate() {
        estimate = nil
        expandedCategoryIDs = []
        do {
            try store.deleteProjectEstimate(projectID: projectID)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func replaceEstimate(_ updated: EstimateTemplate, shouldPersist: Bool) {
        estimate = updated
        if shouldPersist {
            persistCurrentEstimate()
        }
    }

    func persistCurrentEstimate() {
        guard let estimate else { return }
        do {
            try store.saveProjectEstimate(estimate, projectID: projectID)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveReusableTemplate(named rawName: String) async {
        guard let estimate else { return }
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        isSavingTemplate = true
        defer { isSavingTemplate = false }
        do {
            if let service {
                let saved = try await service.saveTemplate(estimate, name: name, projectID: projectID)
                reusableTemplates.removeAll { $0.id == saved.id || $0.name.caseInsensitiveCompare(saved.name) == .orderedSame }
                reusableTemplates.insert(saved, at: 0)
            } else {
                try store.saveReusableTemplate(estimate, name: name)
                reusableTemplates = try store.loadReusableTemplates()
            }
            showStatus("Template saved")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteReusableTemplate(_ template: EstimateTemplate) async {
        do {
            if let service {
                try await service.deleteTemplate(id: template.id)
                reusableTemplates.removeAll { $0.id == template.id }
            }
            showStatus("Template deleted")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
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
        persistCurrentEstimate()
    }

    func renameCategory(_ category: EstimateCategory, to rawName: String) {
        guard var estimate,
              let categoryIndex = estimate.categories.firstIndex(where: { $0.id == category.id }) else { return }
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        estimate.categories[categoryIndex].name = name
        self.estimate = estimate
        persistCurrentEstimate()
    }

    func deleteCategory(_ category: EstimateCategory) {
        guard var estimate else { return }
        estimate.categories.removeAll { $0.id == category.id }
        expandedCategoryIDs.remove(category.id)
        self.estimate = estimate
        persistCurrentEstimate()
    }

    func saveItem(_ item: EstimateItem, isNew: Bool) {
        guard var estimate,
              let categoryIndex = estimate.categories.firstIndex(where: { $0.id == item.categoryID }) else { return }
        if let itemIndex = estimate.categories[categoryIndex].items.firstIndex(where: { $0.id == item.id }) {
            estimate.categories[categoryIndex].items[itemIndex] = item
        } else if isNew {
            estimate.categories[categoryIndex].items.append(item)
        }
        self.estimate = estimate
        expandedCategoryIDs.insert(item.categoryID)
        persistCurrentEstimate()
    }

    func duplicateItem(_ item: EstimateItem, in category: EstimateCategory) {
        guard var estimate,
              let categoryIndex = estimate.categories.firstIndex(where: { $0.id == category.id }) else { return }
        var copy = item
        copy.id = UUID()
        copy.itemName = item.itemName.isEmpty ? "Copy" : "\(item.itemName) Copy"
        estimate.categories[categoryIndex].items.append(copy)
        self.estimate = estimate
        persistCurrentEstimate()
    }

    func deleteItem(_ item: EstimateItem, in category: EstimateCategory) {
        guard var estimate,
              let categoryIndex = estimate.categories.firstIndex(where: { $0.id == category.id }) else { return }
        estimate.categories[categoryIndex].items.removeAll { $0.id == item.id }
        self.estimate = estimate
        persistCurrentEstimate()
    }

    func shouldShowCategory(_ category: EstimateCategory) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if hideUnselectedItems && category.items.allSatisfy({ !$0.selected }) && !category.items.isEmpty {
            return false
        }
        guard !query.isEmpty else { return true }
        return category.name.localizedCaseInsensitiveContains(query)
            || estimateDisplayName(category.name).localizedCaseInsensitiveContains(query)
            || category.items.contains { item in
                item.itemName.localizedCaseInsensitiveContains(query)
                    || item.description.localizedCaseInsensitiveContains(query)
                    || (item.skuSnapshot?.localizedCaseInsensitiveContains(query) ?? false)
                    || (item.brandSnapshot?.localizedCaseInsensitiveContains(query) ?? false)
                    || (item.materialSnapshot?.localizedCaseInsensitiveContains(query) ?? false)
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
}
