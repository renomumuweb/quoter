import SwiftUI

struct DrawingWorkspaceView: View {
    @EnvironmentObject private var appState: AppState
    let project: Project?

    @StateObject private var viewModel = DrawingWorkspaceViewModel()
    @State private var drawingData = Data()
    @State private var selectedObjectID: UUID?
    @State private var selectedAnnotationID: UUID?

    init(project: Project? = nil) {
        self.project = project
    }

    var body: some View {
        HStack(spacing: 0) {
            projectPanel
                .frame(width: 240)
                .background(Color(.secondarySystemGroupedBackground))

            ZStack {
                CanvasGridView()
                PencilCanvasView(drawingData: $drawingData)
                ForEach(viewModel.objects) { object in
                    ProductObjectOverlayView(
                        object: object,
                        isSelected: selectedObjectID == object.id
                    )
                    .onTapGesture {
                        selectedObjectID = object.id
                        selectedAnnotationID = nil
                    }
                }
                ForEach(viewModel.annotations) { annotation in
                    AnnotationOverlayView(annotation: annotation)
                        .onTapGesture {
                            selectedAnnotationID = annotation.id
                            selectedObjectID = nil
                        }
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView("Loading drawing")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .clipped()
            .background(Color(.systemBackground))

            inspectorPanel
                .frame(width: 340)
                .background(Color(.secondarySystemGroupedBackground))
        }
        .navigationTitle(project?.title ?? "Drawing Workspace")
        .navigationBarTitleDisplayMode(.inline)
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
        .task {
            viewModel.configure(apiClient: appState.apiClient, project: project)
            await viewModel.load()
        }
    }

    private var projectPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(project?.title ?? "Preview Project", systemImage: "folder")
                .font(.headline)
            if let project {
                Text(project.customerName ?? "Customer")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(project.roomType.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()
            Text("Layers")
                .font(.subheadline.weight(.semibold))
            Toggle("Drawing", isOn: .constant(true))
            Toggle("Objects", isOn: .constant(true))
            Toggle("Annotations", isOn: .constant(true))

            Divider()
            Button {
                Task { await viewModel.saveDrawing() }
            } label: {
                Label("Save Drawing", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
            .disabled(project == nil)

            Text(project == nil ? "Preview mode uses local sample data." : "Objects and annotations are saved to the self-hosted API.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
    }

    private var inspectorPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Inspector")
                    .font(.headline)

                HStack {
                    Button {
                        Task {
                            let object = await viewModel.addObject(type: "vanity")
                            selectedObjectID = object?.id
                            selectedAnnotationID = nil
                        }
                    } label: {
                        Label("Object", systemImage: "plus.square")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        Task {
                            let annotation = await viewModel.addAnnotation()
                            selectedAnnotationID = annotation?.id
                            selectedObjectID = nil
                        }
                    } label: {
                        Label("Note", systemImage: "text.badge.plus")
                    }
                    .buttonStyle(.bordered)
                }

                Divider()

                if let index = selectedObjectIndex {
                    ObjectInspector(
                        object: $viewModel.objects[index],
                        products: viewModel.products,
                        onSave: { object in await viewModel.saveObject(object) },
                        onDelete: { object in
                            await viewModel.deleteObject(object)
                            selectedObjectID = nil
                        }
                    )
                } else if let index = selectedAnnotationIndex {
                    AnnotationInspector(
                        annotation: $viewModel.annotations[index],
                        objects: viewModel.objects,
                        onSave: { annotation in await viewModel.saveAnnotation(annotation) },
                        onDelete: { annotation in
                            await viewModel.deleteAnnotation(annotation)
                            selectedAnnotationID = nil
                        }
                    )
                } else {
                    ContentUnavailableView {
                        Label("Nothing Selected", systemImage: "hand.tap")
                    } description: {
                        Text("Select an object or annotation, then edit its quote fields here.")
                    }
                    .frame(minHeight: 220)
                }

                Divider()
                QuoteMiniSummary(objects: viewModel.objects)
            }
            .padding()
        }
    }

    private var selectedObjectIndex: Int? {
        guard let selectedObjectID else { return nil }
        return viewModel.objects.firstIndex { $0.id == selectedObjectID }
    }

    private var selectedAnnotationIndex: Int? {
        guard let selectedAnnotationID else { return nil }
        return viewModel.annotations.firstIndex { $0.id == selectedAnnotationID }
    }
}

private struct ObjectInspector: View {
    @Binding var object: DrawingObject
    let products: [Product]
    let onSave: (DrawingObject) async -> Void
    let onDelete: (DrawingObject) async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(object.objectType.capitalized)
                .font(.title3.weight(.semibold))

            TextField("Object Type", text: $object.objectType)
                .textInputAutocapitalization(.never)

            Picker("Product", selection: productSelection) {
                Text("Unbound").tag(Optional<UUID>.none)
                ForEach(products) { product in
                    Text("\(product.name) \(product.currentPrice.map { DecimalFormatter.currency($0) } ?? "")")
                        .tag(Optional(product.id))
                }
            }

            Stepper(value: quantityBinding, in: 0...999, step: 1) {
                LabeledContent("Quantity", value: NSDecimalNumber(decimal: object.quantity).stringValue)
            }
            TextField("Unit", text: $object.unit)
            Stepper(value: discountBinding, in: 0...100_000, step: 25) {
                LabeledContent("Discount", value: DecimalFormatter.currency(object.discountAmount))
            }
            Stepper(value: installBinding, in: 0...100_000, step: 25) {
                LabeledContent("Install Fee", value: DecimalFormatter.currency(object.installationFee))
            }
            TextField("Notes", text: $object.notes, axis: .vertical)
                .lineLimit(2...5)
            Toggle("Include in Quote", isOn: $object.isQuoteEnabled)
            Toggle("Show in Contract", isOn: $object.isContractVisible)

            HStack {
                Button("Save Object") {
                    Task { await onSave(object) }
                }
                .buttonStyle(.borderedProminent)

                Button(role: .destructive) {
                    Task { await onDelete(object) }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var productSelection: Binding<UUID?> {
        Binding {
            object.productID ?? object.serviceID
        } set: { value in
            object.productID = value
            object.serviceID = nil
        }
    }

    private var quantityBinding: Binding<Double> {
        decimalBinding(\.quantity)
    }

    private var discountBinding: Binding<Double> {
        decimalBinding(\.discountAmount)
    }

    private var installBinding: Binding<Double> {
        decimalBinding(\.installationFee)
    }

    private func decimalBinding(_ keyPath: WritableKeyPath<DrawingObject, Decimal>) -> Binding<Double> {
        Binding {
            NSDecimalNumber(decimal: object[keyPath: keyPath]).doubleValue
        } set: { value in
            object[keyPath: keyPath] = Decimal(value)
        }
    }
}

private struct AnnotationInspector: View {
    @Binding var annotation: DrawingAnnotation
    let objects: [DrawingObject]
    let onSave: (DrawingAnnotation) async -> Void
    let onDelete: (DrawingAnnotation) async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Annotation")
                .font(.title3.weight(.semibold))
            Picker("Type", selection: $annotation.annotationType) {
                Text("Note").tag("note")
                Text("Dimension").tag("dimension")
                Text("Area").tag("area")
                Text("Issue").tag("issue")
            }
            TextField("Text", text: $annotation.text, axis: .vertical)
                .lineLimit(2...5)
            Picker("Linked Object", selection: $annotation.linkedObjectID) {
                Text("None").tag(Optional<UUID>.none)
                ForEach(objects) { object in
                    Text(object.objectType.capitalized).tag(Optional(object.id))
                }
            }
            Toggle("Export to PDF", isOn: $annotation.exportToPDF)
            Toggle("Show in Contract", isOn: $annotation.showInContract)
            HStack {
                Button("Save Note") {
                    Task { await onSave(annotation) }
                }
                .buttonStyle(.borderedProminent)
                Button(role: .destructive) {
                    Task { await onDelete(annotation) }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

private struct QuoteMiniSummary: View {
    let objects: [DrawingObject]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quote Readiness")
                .font(.subheadline.weight(.semibold))
            LabeledContent("Objects", value: "\(objects.count)")
            LabeledContent("Quote Enabled", value: "\(objects.filter(\.isQuoteEnabled).count)")
            LabeledContent("Unbound", value: "\(objects.filter { $0.isQuoteEnabled && $0.productID == nil && $0.serviceID == nil }.count)")
        }
        .font(.footnote)
    }
}

@MainActor
final class DrawingWorkspaceViewModel: ObservableObject {
    @Published private(set) var drawing: DrawingRecord?
    @Published var objects: [DrawingObject] = []
    @Published var annotations: [DrawingAnnotation] = []
    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var drawingService: DrawingService?
    private var productService: ProductService?
    private var project: Project?

    func configure(apiClient: APIClient, project: Project?) {
        if drawingService == nil {
            drawingService = DrawingService(apiClient: apiClient)
            productService = ProductService(apiClient: apiClient)
        }
        self.project = project
    }

    func load() async {
        guard let productService else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            async let loadedProducts = productService.listProducts()
            if let project, let drawingService {
                let response = try await drawingService.getDrawing(projectID: project.id)
                drawing = response.drawing
                objects = response.objects
                annotations = response.annotations
            } else {
                objects = [.preview]
                annotations = [.preview]
            }
            products = try await loadedProducts
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveDrawing() async {
        guard let project, let drawing, let drawingService else { return }
        do {
            let response = try await drawingService.updateDrawing(projectID: project.id, drawing: drawing)
            self.drawing = response.drawing
            objects = response.objects
            annotations = response.annotations
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addObject(type: String) async -> DrawingObject? {
        var object = DrawingObject(
            projectID: project?.id,
            drawingID: drawing?.id,
            objectType: type,
            x: 0.42,
            y: 0.38,
            width: 0.2,
            height: 0.12,
            rotation: 0,
            quantity: 1,
            unit: "each",
            discountAmount: 0,
            installationFee: 0,
            notes: "",
            isQuoteEnabled: true,
            isContractVisible: true
        )
        guard let drawingService, project != nil else {
            objects.append(object)
            return object
        }
        do {
            object = try await drawingService.createObject(object)
            objects.append(object)
            errorMessage = nil
            return object
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func saveObject(_ object: DrawingObject) async {
        guard let drawingService, project != nil else {
            replace(object, in: &objects)
            return
        }
        do {
            let updated = try await drawingService.updateObject(object)
            replace(updated, in: &objects)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteObject(_ object: DrawingObject) async {
        guard let drawingService, project != nil else {
            objects.removeAll { $0.id == object.id }
            return
        }
        do {
            try await drawingService.deleteObject(id: object.id)
            objects.removeAll { $0.id == object.id }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addAnnotation() async -> DrawingAnnotation? {
        var annotation = DrawingAnnotation(
            projectID: project?.id,
            drawingID: drawing?.id,
            annotationType: "note",
            text: "New note",
            x: 0.4,
            y: 0.28,
            width: 0.24,
            height: 0.06,
            rotation: 0,
            exportToPDF: true,
            showInContract: true
        )
        guard let drawingService, project != nil else {
            annotations.append(annotation)
            return annotation
        }
        do {
            annotation = try await drawingService.createAnnotation(annotation)
            annotations.append(annotation)
            errorMessage = nil
            return annotation
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func saveAnnotation(_ annotation: DrawingAnnotation) async {
        guard let drawingService, project != nil else {
            replace(annotation, in: &annotations)
            return
        }
        do {
            let updated = try await drawingService.updateAnnotation(annotation)
            replace(updated, in: &annotations)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteAnnotation(_ annotation: DrawingAnnotation) async {
        guard let drawingService, project != nil else {
            annotations.removeAll { $0.id == annotation.id }
            return
        }
        do {
            try await drawingService.deleteAnnotation(id: annotation.id)
            annotations.removeAll { $0.id == annotation.id }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func replace<Item: Identifiable>(_ item: Item, in items: inout [Item]) where Item.ID == UUID {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        }
    }
}

struct DrawingService {
    let apiClient: APIClient

    func getDrawing(projectID: UUID) async throws -> DrawingResponse {
        try await apiClient.get("projects/\(projectID.uuidString)/drawing")
    }

    func updateDrawing(projectID: UUID, drawing: DrawingRecord) async throws -> DrawingResponse {
        try await apiClient.put("projects/\(projectID.uuidString)/drawing", body: drawing)
    }

    func createObject(_ object: DrawingObject) async throws -> DrawingObject {
        try await apiClient.post("drawing-objects", body: object)
    }

    func updateObject(_ object: DrawingObject) async throws -> DrawingObject {
        try await apiClient.put("drawing-objects/\(object.id.uuidString)", body: object)
    }

    func deleteObject(id: UUID) async throws {
        try await apiClient.delete("drawing-objects/\(id.uuidString)")
    }

    func createAnnotation(_ annotation: DrawingAnnotation) async throws -> DrawingAnnotation {
        try await apiClient.post("drawing-annotations", body: annotation)
    }

    func updateAnnotation(_ annotation: DrawingAnnotation) async throws -> DrawingAnnotation {
        try await apiClient.put("drawing-annotations/\(annotation.id.uuidString)", body: annotation)
    }

    func deleteAnnotation(id: UUID) async throws {
        try await apiClient.delete("drawing-annotations/\(id.uuidString)")
    }
}
