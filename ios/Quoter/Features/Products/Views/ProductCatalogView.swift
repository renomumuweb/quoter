import SwiftUI

struct ProductCatalogView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ProductCatalogViewModel()
    @State private var showingNewProduct = false
    @State private var showingNewBrand = false
    @State private var showingNewCategory = false
    @State private var editingProduct: Product?
    @State private var editingBrand: ProductBrand?
    @State private var editingCategory: ProductCategory?
    @State private var selectedScopes: Set<String> = []
    @State private var selectedCategoryID: UUID?
    @State private var selectedBrandID: UUID?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Search products", text: $viewModel.searchText)
                        .textInputAutocapitalization(.never)
                        .onSubmit {
                            Task { await viewModel.loadProducts() }
                        }
                }

                Section("Service Areas") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                        ForEach(Project.serviceScopes, id: \.id) { scope in
                            Button {
                                toggleScope(scope.id)
                            } label: {
                                Label(LocalizedStringKey(scope.title), systemImage: scope.icon)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.bordered)
                            .tint(selectedScopes.contains(scope.id) ? Color.blue : Color.secondary)
                        }
                    }
                }

                Section("1. Category") {
                    if visibleCategories.isEmpty {
                        ContentUnavailableView("No Categories", systemImage: "square.grid.2x2")
                    } else {
                        ForEach(visibleCategories) { category in
                            Button {
                                selectedCategoryID = category.id
                            } label: {
                                HStack {
                                    Label(AppLanguage.localizedKnownSystemString(category.name), systemImage: category.kind == "service" ? "wrench.and.screwdriver" : "shippingbox")
                                    Spacer()
                                    if selectedCategoryID == category.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .swipeActions {
                                Button("Edit") {
                                    editingCategory = category
                                }
                                .tint(.blue)
                            }
                        }
                        .onDelete { offsets in
                            Task { await viewModel.deleteCategories(at: offsets, in: visibleCategories) }
                        }
                    }
                }

                Section("2. Brand") {
                    Button {
                        selectedBrandID = nil
                    } label: {
                        HStack {
                            Label("Any Brand", systemImage: "line.3.horizontal.decrease.circle")
                            Spacer()
                            if selectedBrandID == nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    ForEach(viewModel.brands) { brand in
                        Button {
                            selectedBrandID = brand.id
                        } label: {
                            HStack {
                                Text(brand.name)
                                Spacer()
                                if selectedBrandID == brand.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button("Edit") {
                                editingBrand = brand
                            }
                            .tint(.blue)
                        }
                    }
                    .onDelete { offsets in
                        Task { await viewModel.deleteBrands(at: offsets) }
                    }
                }

                Section("3. Products") {
                    if visibleProducts.isEmpty {
                        ContentUnavailableView("No Products", systemImage: "shippingbox")
                    } else {
                        ForEach(visibleProducts) { product in
                            Button {
                                editingProduct = product
                            } label: {
                                ProductRow(product: product)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { offsets in
                            Task { await viewModel.deleteProducts(at: offsets, in: visibleProducts) }
                        }
                    }
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView("Loading catalog")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .navigationTitle("Product Catalog")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("New Product") { showingNewProduct = true }
                            .disabled(visibleCategories.isEmpty)
                        Button("New Brand") { showingNewBrand = true }
                        Button("New Category") { showingNewCategory = true }
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let message = viewModel.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.regularMaterial)
                }
            }
            .sheet(isPresented: $showingNewProduct) {
                ProductFormView(
                    title: "New Product",
                    categories: viewModel.categories,
                    brands: viewModel.brands,
                    defaultCategoryID: selectedCategoryID ?? visibleCategories.first?.id,
                    defaultBrandID: selectedBrandID
                ) { request in
                    await viewModel.createProduct(request)
                }
            }
            .sheet(item: $editingProduct) { product in
                ProductFormView(
                    title: "Edit Product",
                    product: product,
                    categories: viewModel.categories,
                    brands: viewModel.brands
                ) { request in
                    await viewModel.updateProduct(product, request: request)
                }
            }
            .sheet(isPresented: $showingNewBrand) {
                BrandFormView(title: "New Brand") { request in
                    await viewModel.createBrand(request)
                }
            }
            .sheet(item: $editingBrand) { brand in
                BrandFormView(title: "Edit Brand", brand: brand) { request in
                    await viewModel.updateBrand(brand, request: request)
                }
            }
            .sheet(isPresented: $showingNewCategory) {
                CategoryFormView(title: "New Category") { request in
                    await viewModel.createCategory(request)
                }
            }
            .sheet(item: $editingCategory) { category in
                CategoryFormView(title: "Edit Category", category: category) { request in
                    await viewModel.updateCategory(category, request: request)
                }
            }
            .task {
                viewModel.configure(apiClient: appState.apiClient)
                await viewModel.load()
                ensureCategorySelection()
            }
            .onChange(of: viewModel.searchText) { _, _ in
                Task { await viewModel.debouncedProductSearch() }
            }
            .onChange(of: viewModel.categories) { _, _ in
                ensureCategorySelection()
            }
            .onChange(of: selectedScopes) { _, _ in
                ensureCategorySelection()
            }
        }
    }

    private var visibleCategories: [ProductCategory] {
        viewModel.categories.filter { category in
            selectedScopes.isEmpty || categoryMatchesSelectedScopes(category.name)
        }
    }

    private var visibleProducts: [Product] {
        viewModel.products.filter { product in
            let matchesScope = selectedScopes.isEmpty || categoryMatchesSelectedScopes(product.category)
            let matchesCategory = selectedCategoryID == nil || product.categoryID == selectedCategoryID
            let matchesBrand = selectedBrandID == nil || product.brandID == selectedBrandID
            return matchesScope && matchesCategory && matchesBrand
        }
    }

    private func toggleScope(_ scope: String) {
        if selectedScopes.contains(scope) {
            selectedScopes.remove(scope)
        } else {
            selectedScopes.insert(scope)
        }
    }

    private func ensureCategorySelection() {
        guard !visibleCategories.isEmpty else {
            selectedCategoryID = nil
            return
        }
        if selectedCategoryID == nil || !visibleCategories.contains(where: { $0.id == selectedCategoryID }) {
            selectedCategoryID = visibleCategories.first?.id
        }
    }

    private func categoryMatchesSelectedScopes(_ name: String) -> Bool {
        let value = name.lowercased()
        if selectedScopes.contains("whole_home") {
            return true
        }
        return selectedScopes.contains(where: { scope in
            Self.scopeKeywords[scope, default: [scope]].contains { value.contains($0) }
        })
    }

    private static let scopeKeywords: [String: [String]] = [
        "kitchen": ["kitchen", "cabinet", "sink", "faucet", "backsplash"],
        "bathroom": ["bath", "vanity", "toilet", "shower", "tub", "tile", "install"],
        "flooring": ["floor", "tile", "vinyl", "hardwood", "laminate"],
        "doors_windows": ["door", "window", "trim"],
        "countertops": ["counter", "countertop", "slab", "quartz", "granite"]
    ]
}

private struct ProductRow: View {
    let product: Product

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(product.name)
                    .font(.headline)
                Spacer()
                Text(product.sku)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Label(AppLanguage.localizedKnownSystemString(product.category), systemImage: product.isService ? "wrench.and.screwdriver" : "shippingbox")
                Text(product.brand.isEmpty ? AppLanguage.localizedString("No Brand") : product.brand)
                if let material = product.material, !material.trimmed.isEmpty {
                    Text(material)
                }
                Text(AppLanguage.localizedKnownSystemString(product.unit))
                if let price = product.currentPrice {
                    Text(DecimalFormatter.currency(price))
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if !product.active {
                Text("Inactive")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ProductFormView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let product: Product?
    let categories: [ProductCategory]
    let brands: [ProductBrand]
    let onSave: (ProductUpsertRequest) async -> Void

    @State private var brandID: UUID?
    @State private var categoryID: UUID
    @State private var name: String
    @State private var sku: String
    @State private var size: String
    @State private var color: String
    @State private var material: String
    @State private var unit: String
    @State private var description: String
    @State private var imageURL: String
    @State private var active: Bool
    @State private var isService: Bool
    @State private var currentPrice: String
    @State private var isSaving = false

    init(
        title: String,
        product: Product? = nil,
        categories: [ProductCategory],
        brands: [ProductBrand],
        defaultCategoryID: UUID? = nil,
        defaultBrandID: UUID? = nil,
        onSave: @escaping (ProductUpsertRequest) async -> Void
    ) {
        self.title = title
        self.product = product
        self.categories = categories
        self.brands = brands
        self.onSave = onSave
        _brandID = State(initialValue: product?.brandID ?? defaultBrandID)
        _categoryID = State(initialValue: product?.categoryID ?? defaultCategoryID ?? categories.first?.id ?? UUID())
        _name = State(initialValue: product?.name ?? "")
        _sku = State(initialValue: product?.sku ?? "")
        _size = State(initialValue: product?.size ?? "")
        _color = State(initialValue: product?.color ?? "")
        _material = State(initialValue: product?.material ?? "")
        _unit = State(initialValue: product?.unit ?? "each")
        _description = State(initialValue: product?.description ?? "")
        _imageURL = State(initialValue: product?.imageURL?.absoluteString ?? "")
        _active = State(initialValue: product?.active ?? true)
        _isService = State(initialValue: product?.isService ?? false)
        _currentPrice = State(initialValue: product?.currentPrice.map { NSDecimalNumber(decimal: $0).stringValue } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Product") {
                    Picker("Category", selection: $categoryID) {
                        ForEach(categories) { category in
                            Text("\(AppLanguage.localizedKnownSystemString(category.name)) (\(AppLanguage.localizedKnownSystemString(category.kind)))").tag(category.id)
                        }
                    }
                    Picker("Brand", selection: $brandID) {
                        Text("No Brand").tag(nil as UUID?)
                        ForEach(brands) { brand in
                            Text(brand.name).tag(brand.id as UUID?)
                        }
                    }
                    TextField("Name", text: $name)
                    TextField("SKU", text: $sku)
                        .textInputAutocapitalization(.characters)
                    TextField("Unit", text: $unit)
                    TextField("Current Price", text: $currentPrice)
                        .keyboardType(.decimalPad)
                    Toggle("Active", isOn: $active)
                    Toggle("Service Item", isOn: $isService)
                }
                Section("Attributes") {
                    TextField("Size", text: $size)
                    TextField("Color", text: $color)
                    TextField("Material", text: $material)
                    TextField("Image URL", text: $imageURL)
                        .textInputAutocapitalization(.never)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(LocalizedStringKey(title))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            isSaving = true
                            await onSave(request)
                            isSaving = false
                            dismiss()
                        }
                    } label: {
                        Text(LocalizedStringKey(isSaving ? "Saving" : "Save"))
                    }
                    .disabled(categories.isEmpty || name.trimmed.isEmpty || sku.trimmed.isEmpty || isSaving)
                }
            }
        }
    }

    private var request: ProductUpsertRequest {
        ProductUpsertRequest(
            brandID: brandID,
            categoryID: categoryID,
            name: name.trimmed,
            sku: sku.trimmed,
            size: size.nilIfBlank,
            color: color.nilIfBlank,
            material: material.nilIfBlank,
            unit: unit.trimmed.isEmpty ? "each" : unit.trimmed,
            description: description.nilIfBlank,
            imageURL: imageURL.nilIfBlank,
            active: active,
            isService: isService,
            currentPrice: Decimal(string: currentPrice.trimmed),
            currency: "USD"
        )
    }
}

private struct BrandFormView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let brand: ProductBrand?
    let onSave: (BrandUpsertRequest) async -> Void
    @State private var name: String
    @State private var isSaving = false

    init(title: String, brand: ProductBrand? = nil, onSave: @escaping (BrandUpsertRequest) async -> Void) {
        self.title = title
        self.brand = brand
        self.onSave = onSave
        _name = State(initialValue: brand?.name ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
            }
            .navigationTitle(LocalizedStringKey(title))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            isSaving = true
                            await onSave(BrandUpsertRequest(name: name.trimmed))
                            isSaving = false
                            dismiss()
                        }
                    } label: {
                        Text(LocalizedStringKey(isSaving ? "Saving" : "Save"))
                    }
                    .disabled(name.trimmed.isEmpty || isSaving)
                }
            }
        }
    }
}

private struct CategoryFormView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let category: ProductCategory?
    let onSave: (ProductCategoryUpsertRequest) async -> Void
    @State private var name: String
    @State private var kind: String
    @State private var isSaving = false

    init(title: String, category: ProductCategory? = nil, onSave: @escaping (ProductCategoryUpsertRequest) async -> Void) {
        self.title = title
        self.category = category
        self.onSave = onSave
        _name = State(initialValue: category?.name ?? "")
        _kind = State(initialValue: category?.kind ?? "product")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                Picker("Kind", selection: $kind) {
                    Text("Product").tag("product")
                    Text("Service").tag("service")
                }
            }
            .navigationTitle(LocalizedStringKey(title))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            isSaving = true
                            await onSave(ProductCategoryUpsertRequest(parentID: nil, name: name.trimmed, kind: kind))
                            isSaving = false
                            dismiss()
                        }
                    } label: {
                        Text(LocalizedStringKey(isSaving ? "Saving" : "Save"))
                    }
                    .disabled(name.trimmed.isEmpty || isSaving)
                }
            }
        }
    }
}

@MainActor
final class ProductCatalogViewModel: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var categories: [ProductCategory] = []
    @Published private(set) var brands: [ProductBrand] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""

    private var service: ProductService?
    private var searchTask: Task<Void, Never>?

    func configure(apiClient: APIClient) {
        if service == nil {
            service = ProductService(apiClient: apiClient)
        }
    }

    func load() async {
        guard let service else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            async let loadedBrands = service.listBrands()
            async let loadedCategories = service.listCategories()
            async let loadedProducts = service.listProducts(query: searchText)
            brands = try await loadedBrands
            categories = try await loadedCategories
            products = try await loadedProducts
            errorMessage = nil
        } catch {
            errorMessage = AppLanguage.localizedErrorDescription(error)
        }
    }

    func loadProducts() async {
        guard let service else { return }
        do {
            products = try await service.listProducts(query: searchText)
            errorMessage = nil
        } catch {
            errorMessage = AppLanguage.localizedErrorDescription(error)
        }
    }

    func debouncedProductSearch() async {
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await self?.loadProducts()
        }
    }

    func createProduct(_ request: ProductUpsertRequest) async {
        await perform {
            let product = try await serviceRequired().createProduct(request)
            products.insert(product, at: 0)
        }
    }

    func updateProduct(_ product: Product, request: ProductUpsertRequest) async {
        await perform {
            let updated = try await serviceRequired().updateProduct(id: product.id, request: request)
            replace(updated, in: &products)
        }
    }

    func deleteProducts(at offsets: IndexSet, in source: [Product]? = nil) async {
        let productsToDelete = source ?? products
        for index in offsets {
            let product = productsToDelete[index]
            await perform {
                try await serviceRequired().deleteProduct(id: product.id)
                products.removeAll { $0.id == product.id }
            }
        }
    }

    func createBrand(_ request: BrandUpsertRequest) async {
        await perform {
            let brand = try await serviceRequired().createBrand(request)
            brands.append(brand)
            brands.sort { $0.name < $1.name }
        }
    }

    func updateBrand(_ brand: ProductBrand, request: BrandUpsertRequest) async {
        await perform {
            let updated = try await serviceRequired().updateBrand(id: brand.id, request: request)
            replace(updated, in: &brands)
        }
    }

    func deleteBrands(at offsets: IndexSet) async {
        for index in offsets {
            let brand = brands[index]
            await perform {
                try await serviceRequired().deleteBrand(id: brand.id)
                brands.removeAll { $0.id == brand.id }
            }
        }
    }

    func createCategory(_ request: ProductCategoryUpsertRequest) async {
        await perform {
            let category = try await serviceRequired().createCategory(request)
            categories.append(category)
            categories.sort { $0.name < $1.name }
        }
    }

    func updateCategory(_ category: ProductCategory, request: ProductCategoryUpsertRequest) async {
        await perform {
            let updated = try await serviceRequired().updateCategory(id: category.id, request: request)
            replace(updated, in: &categories)
        }
    }

    func deleteCategories(at offsets: IndexSet, in source: [ProductCategory]? = nil) async {
        let categoriesToDelete = source ?? categories
        for index in offsets {
            let category = categoriesToDelete[index]
            await perform {
                try await serviceRequired().deleteCategory(id: category.id)
                categories.removeAll { $0.id == category.id }
            }
        }
    }

    private func perform(_ operation: () async throws -> Void) async {
        do {
            try await operation()
            errorMessage = nil
        } catch {
            errorMessage = AppLanguage.localizedErrorDescription(error)
        }
    }

    private func serviceRequired() throws -> ProductService {
        guard let service else { throw APIError.invalidResponse }
        return service
    }

    private func replace<Item: Identifiable>(_ item: Item, in items: inout [Item]) where Item.ID == UUID {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        }
    }
}

struct ProductService {
    let apiClient: APIClient

    func listProducts(query: String = "") async throws -> [Product] {
        let trimmed = query.trimmed
        let suffix = trimmed.isEmpty ? "" : "?q=\(trimmed.urlQueryEscaped)"
        let response: ListResponse<Product> = try await apiClient.get("products\(suffix)")
        return response.items
    }

    func createProduct(_ request: ProductUpsertRequest) async throws -> Product {
        try await apiClient.post("products", body: request)
    }

    func updateProduct(id: UUID, request: ProductUpsertRequest) async throws -> Product {
        try await apiClient.put("products/\(id.uuidString)", body: request)
    }

    func deleteProduct(id: UUID) async throws {
        try await apiClient.delete("products/\(id.uuidString)")
    }

    func listBrands() async throws -> [ProductBrand] {
        let response: ListResponse<ProductBrand> = try await apiClient.get("brands")
        return response.items
    }

    func createBrand(_ request: BrandUpsertRequest) async throws -> ProductBrand {
        try await apiClient.post("brands", body: request)
    }

    func updateBrand(id: UUID, request: BrandUpsertRequest) async throws -> ProductBrand {
        try await apiClient.put("brands/\(id.uuidString)", body: request)
    }

    func deleteBrand(id: UUID) async throws {
        try await apiClient.delete("brands/\(id.uuidString)")
    }

    func listCategories() async throws -> [ProductCategory] {
        let response: ListResponse<ProductCategory> = try await apiClient.get("product-categories")
        return response.items
    }

    func createCategory(_ request: ProductCategoryUpsertRequest) async throws -> ProductCategory {
        try await apiClient.post("product-categories", body: request)
    }

    func updateCategory(id: UUID, request: ProductCategoryUpsertRequest) async throws -> ProductCategory {
        try await apiClient.put("product-categories/\(id.uuidString)", body: request)
    }

    func deleteCategory(id: UUID) async throws {
        try await apiClient.delete("product-categories/\(id.uuidString)")
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var nilIfBlank: String? {
        let value = trimmed
        return value.isEmpty ? nil : value
    }

    var urlQueryEscaped: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}
