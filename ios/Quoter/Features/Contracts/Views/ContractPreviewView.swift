import SwiftUI

struct ContractPreviewView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ContractPreviewViewModel()
    @State private var pdfURL: URL?
    @State private var showingShareSheet = false

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
                                pdfURL = try? PDFGenerator().makeContractPDF(
                                    title: contract.contractNumber,
                                    lines: viewModel.pdfLines(for: contract)
                                )
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    List {
                        Section("Contracts") {
                            ForEach(viewModel.contracts) { contract in
                                Button {
                                    viewModel.selectedContractID = contract.id
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
            .task {
                viewModel.configure(apiClient: appState.apiClient)
                await viewModel.load()
            }
        }
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

    func pdfLines(for contract: Contract) -> [String] {
        [
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
