import Foundation
import MessageUI
import SwiftUI

private func quoteScopeDisplayName(_ value: String) -> String {
    AppLanguage.localizedKnownSystemString(value)
}

struct QuotePreviewView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var localization: AppLocalization
    let project: Project?
    @StateObject private var viewModel: QuotePreviewViewModel
    @State private var pdfURL: URL?
    @State private var showingShareSheet = false
    @State private var showingMailComposer = false
    @State private var pdfRecipient = ""

    init(project: Project? = nil) {
        self.project = project
        _viewModel = StateObject(wrappedValue: QuotePreviewViewModel(initialProjectID: project?.id))
    }

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
                    if project == nil {
                        Picker("Project", selection: $viewModel.selectedProjectID) {
                            ForEach(viewModel.projects) { project in
                                Text(project.title).tag(project.id as UUID?)
                            }
                        }
                        .pickerStyle(.menu)
                    } else if let project {
                        Label(project.title, systemImage: "folder")
                            .font(.headline)
                    }

                    HStack {
                        Button("Preview Quote") {
                            pdfURL = nil
                            Task { await viewModel.previewSelectedProject() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.selectedProjectID == nil)

                        Button("Create Quote") {
                            pdfURL = nil
                            Task { await viewModel.createQuote() }
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.preview?.items.isEmpty ?? true)

                        if let quote = viewModel.createdQuote, quote.status != "confirmed" {
                            Button("Confirm") {
                                Task { await viewModel.confirmQuote() }
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    if let quote = viewModel.createdQuote {
                        Label("\(copy("Created")) \(quote.quoteNumber) · \(AppLanguage.localizedStatus(quote.status, language: localization.language))", systemImage: "checkmark.circle")
                            .foregroundStyle(quote.status == "confirmed" ? .green : .blue)
                    }

                    Divider()

                    if let preview = viewModel.preview {
                        QuotePreviewContent(preview: preview)
                        quotePDFControls(preview: preview)
                    } else {
                        ContentUnavailableView {
                            Label("No Preview", systemImage: "list.bullet.rectangle")
                        } description: {
                            Text("Select a project to calculate pending quote scope items.")
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
                pdfURL = nil
                Task { await viewModel.previewSelectedProject() }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let pdfURL = pdfURL {
                    ShareSheet(items: [pdfURL])
                }
            }
            .sheet(isPresented: $showingMailComposer) {
                if let pdfURL = pdfURL {
                    PDFMailComposer(
                        pdfURL: pdfURL,
                        recipient: pdfRecipient.trimmingCharacters(in: .whitespacesAndNewlines),
                        subject: mailSubject,
                        body: mailBody,
                        onFinish: handleMailResult
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func quotePDFControls(preview: QuotePreview) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button("Generate Quote PDF") {
                    generatePDF(for: preview)
                }
                .buttonStyle(.bordered)

                if pdfURL != nil {
                    Button("Share PDF") {
                        showingShareSheet = true
                    }
                    .buttonStyle(.bordered)
                }
            }

            if let pdfURL = pdfURL {
                PDFPreviewView(url: pdfURL)
                    .frame(minHeight: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                TextField("Recipient email", text: $pdfRecipient)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)

                Button("Email PDF") {
                    emailPDF()
                }
                .buttonStyle(.borderedProminent)
                .disabled(pdfRecipient.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var mailSubject: String {
        copy("Quote PDF")
    }

    private var mailBody: String {
        copy("Hello, the generated quote PDF is attached.")
    }

    private func generatePDF(for preview: QuotePreview) {
        let title = viewModel.createdQuote?.quoteNumber ?? copy("Scope / Estimate Request")
        do {
            pdfURL = try PDFGenerator().makeQuotePDF(
                title: title,
                lines: viewModel.pdfLines(for: preview, language: localization.language),
                language: localization.language
            )
            viewModel.errorMessage = nil
        } catch {
            viewModel.errorMessage = localizedPDFError("PDF export failed", error: error)
        }
    }

    private func emailPDF() {
        guard let pdfURL = pdfURL, FileManager.default.fileExists(atPath: pdfURL.path) else {
            viewModel.errorMessage = copy("Generate a PDF first.")
            return
        }
        let recipient = pdfRecipient.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidEmail(recipient) else {
            viewModel.errorMessage = copy("The recipient email is invalid.")
            return
        }
        guard PDFMailComposer.canSendMail else {
            viewModel.errorMessage = copy("Mail is not configured on this device. You can still use Share PDF.")
            return
        }
        viewModel.errorMessage = nil
        showingMailComposer = true
    }

    private func handleMailResult(_ result: Result<MFMailComposeResult, Error>) {
        switch result {
        case let .success(mailResult):
            switch mailResult {
            case .sent:
                viewModel.errorMessage = copy("Email sent.")
            case .saved:
                viewModel.errorMessage = copy("Email saved as a draft.")
            case .cancelled:
                viewModel.errorMessage = nil
            case .failed:
                viewModel.errorMessage = copy("Email failed. Please retry or use Share PDF.")
            default:
                viewModel.errorMessage = nil
            }
        case let .failure(error):
            viewModel.errorMessage = localizedPDFError("Email failed", error: error)
        }
    }

    private func localizedPDFError(_ prefix: String, error: Error) -> String {
        localization.language == .english ? "\(copy(prefix)): \(error.localizedDescription)" : copy(prefix)
    }

    private func copy(_ key: String) -> String {
        AppLanguage.localizedString(key, language: localization.language)
    }

    private func isValidEmail(_ email: String) -> Bool {
        let parts = email.split(separator: "@")
        guard parts.count == 2 else { return false }
        return parts[1].contains(".")
    }
}

private struct QuotePreviewContent: View {
    @EnvironmentObject private var localization: AppLocalization
    let preview: QuotePreview

    var body: some View {
        List {
            if !preview.warnings.isEmpty {
                Section("Warnings") {
                    ForEach(preview.warnings) { warning in
                        Label(warning.localizedMessage(language: localization.language), systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
            }

            Section("Items") {
                if preview.items.isEmpty {
                    Text("No selected quote scope items yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(preview.items) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(item.productNameSnapshot)
                                    .font(.headline)
                                Spacer()
                                Text(item.pricingStatus == "priced" ? DecimalFormatter.currency(item.lineTotal) : "Pending")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(item.pricingStatus == "priced" ? .primary : .orange)
                            }
                            FlowSummaryRow(item: item)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let room = item.roomSnapshot, !room.isEmpty {
                                Label(room, systemImage: "square.split.bottomrightquarter")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let material = item.materialSnapshot, !material.isEmpty {
                                Label(material, systemImage: "swatchpalette")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let suppliedBy = item.suppliedBySnapshot, !suppliedBy.isEmpty {
                                Label("Supplied by \(suppliedBy)", systemImage: "shippingbox")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if !item.notesSnapshot.isEmpty {
                                Text(item.notesSnapshot)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if preview.hasPricedItems {
                Section("Totals") {
                    LabeledContent("Subtotal", value: DecimalFormatter.currency(preview.subtotal))
                    LabeledContent("Discount", value: DecimalFormatter.currency(preview.discountTotal))
                    LabeledContent("Tax", value: DecimalFormatter.currency(preview.taxTotal))
                    LabeledContent("Total", value: DecimalFormatter.currency(preview.total))
                        .font(.headline)
                }
            } else {
                Section("Pricing") {
                    Label("Pricing pending", systemImage: "clock.badge.exclamationmark")
                        .foregroundStyle(.orange)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

private struct FlowSummaryRow: View {
    let item: QuoteItemPreview

    var body: some View {
        HStack(spacing: 12) {
            if let scope = item.scopeSnapshot, !scope.isEmpty {
                Text(quoteScopeDisplayName(scope))
            }
            Text("\(AppLanguage.localizedString("Qty")) \(NSDecimalNumber(decimal: item.quantity).stringValue)")
            Text(AppLanguage.localizedKnownSystemString(item.unitSnapshot))
            if !item.skuSnapshot.isEmpty {
                Text(item.skuSnapshot)
            }
        }
    }
}

private extension UnboundQuoteWarning {
    func localizedMessage(language: AppLanguage) -> String {
        let objectName = AppLanguage.localizedKnownSystemString(objectType, language: language)
        if message.hasPrefix("Unbound product object:") {
            return AppLanguage.localizedFormat("Unbound product object: %@", language: language, objectName)
        }
        if message.hasPrefix("Missing active price for") {
            return AppLanguage.localizedFormat("Missing active price for %@", language: language, objectName)
        }
        return AppLanguage.localizedKnownSystemString(message, language: language)
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

    private let initialProjectID: UUID?
    private var projectService: ProjectService?
    private var quoteService: QuoteService?

    init(initialProjectID: UUID? = nil) {
        self.initialProjectID = initialProjectID
        self.selectedProjectID = initialProjectID
    }

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
                selectedProjectID = initialProjectID ?? projects.first?.id
            }
            errorMessage = nil
            await previewSelectedProject()
        } catch {
            errorMessage = AppLanguage.localizedErrorDescription(error)
        }
    }

    func previewSelectedProject() async {
        guard let quoteService, let selectedProjectID else { return }
        do {
            preview = try await quoteService.previewQuote(projectID: selectedProjectID)
            createdQuote = nil
            errorMessage = nil
        } catch {
            errorMessage = AppLanguage.localizedErrorDescription(error)
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
            errorMessage = AppLanguage.localizedErrorDescription(error)
        }
    }

    func confirmQuote() async {
        guard let quoteService, let quoteID = createdQuote?.id else { return }
        do {
            createdQuote = try await quoteService.confirmQuote(id: quoteID)
            errorMessage = nil
        } catch {
            errorMessage = AppLanguage.localizedErrorDescription(error)
        }
    }

    func pdfLines(for preview: QuotePreview, language: AppLanguage) -> [String] {
        var lines = [
            "\(AppLanguage.localizedString("Project ID", language: language)): \(uuidText(preview.projectID, language: language))",
            "\(AppLanguage.localizedString("Customer ID", language: language)): \(uuidText(preview.customerID, language: language))",
            "\(AppLanguage.localizedString("Pricing", language: language)): \(preview.hasPricedItems ? text(preview.currency, language: language) : AppLanguage.localizedString("Pricing pending", language: language))"
        ]
        if !preview.warnings.isEmpty {
            lines.append("\(AppLanguage.localizedString("Warnings", language: language)):")
            lines.append(contentsOf: preview.warnings.map { "- \($0.localizedMessage(language: language))" })
        }
        lines.append("\(AppLanguage.localizedString("Items", language: language)):")
        lines.append(contentsOf: preview.items.map { item in
            let details = nonEmptyPDFParts([
                item.roomSnapshot.map { "\(AppLanguage.localizedString("Room", language: language)): \($0)" },
                item.scopeSnapshot.map { "\(AppLanguage.localizedString("Scope", language: language)): \($0)" },
                item.materialSnapshot.map { "\(AppLanguage.localizedString("Material", language: language)): \($0)" },
                "\(AppLanguage.localizedString("Qty", language: language)) \(NSDecimalNumber(decimal: item.quantity).stringValue) \(item.unitSnapshot)",
                item.suppliedBySnapshot.map { "\(AppLanguage.localizedString("Supplied By", language: language)): \($0)" },
                item.pricingStatus == "priced" ? DecimalFormatter.currency(item.lineTotal) : AppLanguage.localizedString("Pricing pending", language: language)
            ])
            return "- \(item.productNameSnapshot) / \(details.joined(separator: " / "))"
        })
        if preview.hasPricedItems {
            lines.append("\(AppLanguage.localizedString("Subtotal", language: language)): \(DecimalFormatter.currency(preview.subtotal))")
            lines.append("\(AppLanguage.localizedString("Discount", language: language)): \(DecimalFormatter.currency(preview.discountTotal))")
            lines.append("\(AppLanguage.localizedString("Tax", language: language)): \(DecimalFormatter.currency(preview.taxTotal))")
            lines.append("\(AppLanguage.localizedString("Total", language: language)): \(DecimalFormatter.currency(preview.total))")
        } else {
            lines.append(AppLanguage.localizedString("Pricing pending", language: language))
        }
        return lines
    }

    private func nonEmptyPDFParts(_ values: [String?]) -> [String] {
        values.compactMap { value in
            guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
            return value
        }
    }

    private func uuidText(_ id: UUID?, language: AppLanguage) -> String {
        if let id = id {
            return id.uuidString
        }
        return AppLanguage.localizedString("Not provided", language: language)
    }

    private func text(_ value: String?, language: AppLanguage) -> String {
        guard let value = value, !value.isEmpty else {
            return AppLanguage.localizedString("Not provided", language: language)
        }
        return value
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
