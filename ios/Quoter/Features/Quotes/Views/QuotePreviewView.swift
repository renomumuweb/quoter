import SwiftUI

struct QuotePreviewView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = QuotePreviewViewModel()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.projects.isEmpty {
                    ContentUnavailableView {
                        Label("No Projects", systemImage: "folder")
                    } description: {
                        Text("Create a project and add quote-enabled drawing objects first.")
                    }
                } else {
                    Picker("Project", selection: $viewModel.selectedProjectID) {
                        ForEach(viewModel.projects) { project in
                            Text(project.title).tag(Optional(project.id))
                        }
                    }
                    .pickerStyle(.menu)

                    HStack {
                        Button("Preview Quote") {
                            Task { await viewModel.previewSelectedProject() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.selectedProjectID == nil)

                        Button("Create Quote") {
                            Task { await viewModel.createQuote() }
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.preview == nil)

                        if let quote = viewModel.createdQuote, quote.status != "confirmed" {
                            Button("Confirm") {
                                Task { await viewModel.confirmQuote() }
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    if let quote = viewModel.createdQuote {
                        Label("Created \(quote.quoteNumber) · \(quote.status.capitalized)", systemImage: "checkmark.circle")
                            .foregroundStyle(quote.status == "confirmed" ? .green : .blue)
                    }

                    Divider()

                    if let preview = viewModel.preview {
                        QuotePreviewContent(preview: preview)
                    } else {
                        ContentUnavailableView {
                            Label("No Preview", systemImage: "list.bullet.rectangle")
                        } description: {
                            Text("Select a project to calculate quote items from structured drawing objects.")
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Quote")
            .overlay {
                if viewModel.isLoading {
                    ProgressView("Loading quote")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
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
            .task {
                viewModel.configure(apiClient: appState.apiClient)
                await viewModel.loadProjects()
            }
            .onChange(of: viewModel.selectedProjectID) { _, _ in
                Task { await viewModel.previewSelectedProject() }
            }
        }
    }
}

private struct QuotePreviewContent: View {
    let preview: QuotePreview

    var body: some View {
        List {
            if !preview.warnings.isEmpty {
                Section("Warnings") {
                    ForEach(preview.warnings) { warning in
                        Label(warning.message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
            }

            Section("Items") {
                if preview.items.isEmpty {
                    Text("No quote items yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(preview.items) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(item.productNameSnapshot)
                                    .font(.headline)
                                Spacer()
                                Text(DecimalFormatter.currency(item.lineTotal))
                                    .font(.headline)
                            }
                            HStack(spacing: 12) {
                                Text(item.skuSnapshot)
                                Text("Qty \(NSDecimalNumber(decimal: item.quantity).stringValue)")
                                Text(DecimalFormatter.currency(item.unitPriceSnapshot))
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            if !item.notesSnapshot.isEmpty {
                                Text(item.notesSnapshot)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section("Totals") {
                LabeledContent("Subtotal", value: DecimalFormatter.currency(preview.subtotal))
                LabeledContent("Discount", value: DecimalFormatter.currency(preview.discountTotal))
                LabeledContent("Tax", value: DecimalFormatter.currency(preview.taxTotal))
                LabeledContent("Total", value: DecimalFormatter.currency(preview.total))
                    .font(.headline)
            }
        }
        .listStyle(.insetGrouped)
    }
}

@MainActor
final class QuotePreviewViewModel: ObservableObject {
    @Published private(set) var projects: [Project] = []
    @Published var selectedProjectID: UUID?
    @Published private(set) var preview: QuotePreview?
    @Published private(set) var createdQuote: Quote?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var projectService: ProjectService?
    private var quoteService: QuoteService?

    func configure(apiClient: APIClient) {
        if projectService == nil {
            projectService = ProjectService(apiClient: apiClient)
            quoteService = QuoteService(apiClient: apiClient)
        }
    }

    func loadProjects() async {
        guard let projectService else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            projects = try await projectService.listProjects()
            if selectedProjectID == nil {
                selectedProjectID = projects.first?.id
            }
            errorMessage = nil
            await previewSelectedProject()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func previewSelectedProject() async {
        guard let quoteService, let selectedProjectID else { return }
        do {
            preview = try await quoteService.previewQuote(projectID: selectedProjectID)
            createdQuote = nil
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createQuote() async {
        guard let quoteService, let selectedProjectID else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let quote = try await quoteService.createQuote(projectID: selectedProjectID)
            createdQuote = quote
            preview = QuotePreview(
                customerID: quote.customerID,
                projectID: quote.projectID,
                drawingID: quote.drawingID,
                items: quote.items,
                warnings: quote.warnings ?? [],
                currency: quote.currency,
                subtotal: quote.subtotal,
                discountTotal: quote.discountTotal,
                taxRate: quote.taxRate,
                taxTotal: quote.taxTotal,
                total: quote.total
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func confirmQuote() async {
        guard let quoteService, let quoteID = createdQuote?.id else { return }
        do {
            createdQuote = try await quoteService.confirmQuote(id: quoteID)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct QuoteService {
    let apiClient: APIClient

    func previewQuote(projectID: UUID) async throws -> QuotePreview {
        try await apiClient.post("projects/\(projectID.uuidString)/quotes/preview", body: EmptyRequest())
    }

    func createQuote(projectID: UUID) async throws -> Quote {
        try await apiClient.post("projects/\(projectID.uuidString)/quotes", body: EmptyRequest())
    }

    func getQuote(id: UUID) async throws -> Quote {
        try await apiClient.get("quotes/\(id.uuidString)")
    }

    func confirmQuote(id: UUID) async throws -> Quote {
        try await apiClient.post("quotes/\(id.uuidString)/confirm", body: EmptyRequest())
    }
}
