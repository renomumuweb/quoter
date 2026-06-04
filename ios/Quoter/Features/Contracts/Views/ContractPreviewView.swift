import Foundation
import MessageUI
import SwiftUI

struct ContractPreviewView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var localization: AppLocalization
    @StateObject private var viewModel = ContractPreviewViewModel()
    @State private var pdfURL: URL?
    @State private var showingShareSheet = false
    @State private var showingMailComposer = false
    @State private var pdfRecipient = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.quotes.isEmpty {
                    ContentUnavailableView {
                        Label("No Quotes", systemImage: "doc.text")
                    } description: {
                        Text("Create a quote before generating a contract.")
                    }
                } else {
                    Picker("Quote", selection: $viewModel.selectedQuoteID) {
                        ForEach(viewModel.quotes) { quote in
                            Text("\(quote.quoteNumber) · \(DecimalFormatter.currency(quote.total))").tag(Optional(quote.id))
                        }
                    }
                    .pickerStyle(.menu)

                    HStack {
                        Button("Create Contract") {
                            pdfURL = nil
                            Task { await viewModel.createContract() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.selectedQuoteID == nil)

                        if let contract = viewModel.selectedContract {
                            Button("Register PDF") {
                                Task { await viewModel.registerPDF(for: contract) }
                            }
                            .buttonStyle(.bordered)

                            Button("Generate Local PDF") {
                                generatePDF(for: contract)
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    List {
                        Section("Contracts") {
                            ForEach(viewModel.contracts) { contract in
                            Button {
                                viewModel.selectedContractID = contract.id
                                pdfURL = nil
                            } label: {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(contract.contractNumber)
                                                .font(.headline)
                                            Text(contract.status.capitalized)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if contract.pdfFileAssetID != nil {
                                            Image(systemName: "doc.richtext.fill")
                                                .foregroundStyle(.green)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)

                    if let pdfURL {
                        PDFPreviewView(url: pdfURL)
                            .frame(minHeight: 320)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        Button("Share PDF") {
                            showingShareSheet = true
                        }
                        .buttonStyle(.bordered)

                        VStack(alignment: .leading, spacing: 8) {
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
            }
            .padding()
            .navigationTitle("Contract")
            .overlay {
                if viewModel.isLoading {
                    ProgressView("Loading contracts")
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
            .sheet(isPresented: $showingShareSheet) {
                if let pdfURL {
                    ShareSheet(items: [pdfURL])
                }
            }
            .sheet(isPresented: $showingMailComposer) {
                if let pdfURL {
                    PDFMailComposer(
                        pdfURL: pdfURL,
                        recipient: pdfRecipient.trimmingCharacters(in: .whitespacesAndNewlines),
                        subject: mailSubject,
                        body: mailBody,
                        onFinish: handleMailResult
                    )
                }
            }
            .task {
                viewModel.configure(apiClient: appState.apiClient)
                await viewModel.load()
            }
        }
    }

    private var mailSubject: String {
        if localization.language == .simplifiedChinese {
            return "合同 PDF"
        }
        return "Contract PDF"
    }

    private var mailBody: String {
        if localization.language == .simplifiedChinese {
            return "您好，附件是已生成的合同 PDF。"
        }
        return "Hello, the generated contract PDF is attached."
    }

    private func generatePDF(for contract: Contract) {
        do {
            pdfURL = try PDFGenerator().makeContractPDF(
                title: contract.contractNumber,
                lines: viewModel.pdfLines(for: contract, language: localization.language),
                language: localization.language
            )
            viewModel.errorMessage = nil
        } catch {
            viewModel.errorMessage = localizedPDFError("PDF export failed", error: error)
        }
    }

    private func emailPDF() {
        guard let pdfURL, FileManager.default.fileExists(atPath: pdfURL.path) else {
            viewModel.errorMessage = localization.language == .simplifiedChinese ? "请先生成 PDF。" : "Generate a PDF first."
            return
        }
        let recipient = pdfRecipient.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidEmail(recipient) else {
            viewModel.errorMessage = localization.language == .simplifiedChinese ? "邮箱格式不正确，请检查收件人。" : "The recipient email is invalid."
            return
        }
        guard PDFMailComposer.canSendMail else {
            viewModel.errorMessage = localization.language == .simplifiedChinese ? "此设备没有配置系统邮件账户，无法直接发送。你仍然可以使用“分享 PDF”。" : "Mail is not configured on this device. You can still use Share PDF."
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
                viewModel.errorMessage = localization.language == .simplifiedChinese ? "邮件已发送。" : "Email sent."
            case .saved:
                viewModel.errorMessage = localization.language == .simplifiedChinese ? "邮件已存为草稿。" : "Email saved as a draft."
            case .cancelled:
                viewModel.errorMessage = nil
            case .failed:
                viewModel.errorMessage = localization.language == .simplifiedChinese ? "邮件发送失败，请重试或使用分享 PDF。" : "Email failed. Please retry or use Share PDF."
            @unknown default:
                viewModel.errorMessage = nil
            }
        case let .failure(error):
            viewModel.errorMessage = localizedPDFError("Email failed", error: error)
        }
    }

    private func localizedPDFError(_ prefix: String, error: Error) -> String {
        if localization.language == .simplifiedChinese {
            return "\(prefix == "Email failed" ? "邮件发送失败" : "PDF 导出失败")：\(error.localizedDescription)"
        }
        return "\(prefix): \(error.localizedDescription)"
    }

    private func isValidEmail(_ email: String) -> Bool {
        let parts = email.split(separator: "@")
        guard parts.count == 2 else { return false }
        return parts[1].contains(".")
    }
}

@MainActor
final class ContractPreviewViewModel: ObservableObject {
    @Published private(set) var quotes: [Quote] = []
    @Published private(set) var contracts: [Contract] = []
    @Published var selectedQuoteID: UUID?
    @Published var selectedContractID: UUID?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var service: ContractService?

    var selectedContract: Contract? {
        guard let selectedContractID else { return contracts.first }
        return contracts.first { $0.id == selectedContractID }
    }

    func configure(apiClient: APIClient) {
        if service == nil {
            service = ContractService(apiClient: apiClient)
        }
    }

    func load() async {
        guard let service else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            async let loadedQuotes = service.listQuotes()
            async let loadedContracts = service.listContracts()
            quotes = try await loadedQuotes
            contracts = try await loadedContracts
            selectedQuoteID = selectedQuoteID ?? quotes.first?.id
            selectedContractID = selectedContractID ?? contracts.first?.id
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createContract() async {
        guard let service, let selectedQuoteID else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let contract = try await service.createContract(quoteID: selectedQuoteID)
            contracts.insert(contract, at: 0)
            selectedContractID = contract.id
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func registerPDF(for contract: Contract) async {
        guard let service else { return }
        do {
            let updated = try await service.createPDFRecord(contractID: contract.id)
            if let index = contracts.firstIndex(where: { $0.id == updated.id }) {
                contracts[index] = updated
            }
            selectedContractID = updated.id
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func pdfLines(for contract: Contract, language: AppLanguage) -> [String] {
        if language == .simplifiedChinese {
            return [
                "合同编号：\(contract.contractNumber)",
                "状态：\(contract.status.capitalized)",
                "付款条款：\(contract.paymentTerms)",
                "交付条款：\(contract.deliveryTerms)",
                "免责声明：\(contract.disclaimer)",
                "画图附件和报价快照已保存在后端合同记录中。"
            ]
        }
        return [
            "Contract: \(contract.contractNumber)",
            "Status: \(contract.status.capitalized)",
            "Payment Terms: \(contract.paymentTerms)",
            "Delivery Terms: \(contract.deliveryTerms)",
            "Disclaimer: \(contract.disclaimer)",
            "Drawing attachment and quote snapshot are stored in the backend contract record."
        ]
    }
}

struct Contract: Codable, Identifiable, Hashable {
    let id: UUID
    var quoteID: UUID
    var contractTemplateID: UUID?
    var pdfFileAssetID: UUID?
    var contractNumber: String
    var status: String
    var paymentTerms: String
    var deliveryTerms: String
    var disclaimer: String
    var issuedAt: Date?
    var signedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case quoteID = "quoteId"
        case contractTemplateID = "contractTemplateId"
        case pdfFileAssetID = "pdfFileAssetId"
        case contractNumber
        case status
        case paymentTerms
        case deliveryTerms
        case disclaimer
        case issuedAt
        case signedAt
        case createdAt
        case updatedAt
    }
}

struct ContractService {
    let apiClient: APIClient

    func listQuotes() async throws -> [Quote] {
        let response: ListResponse<Quote> = try await apiClient.get("quotes")
        return response.items
    }

    func listContracts() async throws -> [Contract] {
        let response: ListResponse<Contract> = try await apiClient.get("contracts")
        return response.items
    }

    func createContract(quoteID: UUID) async throws -> Contract {
        try await apiClient.post("quotes/\(quoteID.uuidString)/contracts", body: EmptyRequest())
    }

    func createPDFRecord(contractID: UUID) async throws -> Contract {
        try await apiClient.post("contracts/\(contractID.uuidString)/pdf", body: EmptyRequest())
    }
}
