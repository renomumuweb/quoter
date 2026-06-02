import SwiftUI

struct CustomerListView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = CustomerListViewModel()
    @State private var showingNewCustomer = false
    @State private var editingCustomer: Customer?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.customers.isEmpty {
                    ProgressView("Loading customers")
                } else if viewModel.customers.isEmpty {
                    ContentUnavailableView {
                        Label("No Customers", systemImage: "person.2")
                    } description: {
                        Text("Create a customer before starting a project.")
                    } actions: {
                        Button("New Customer") {
                            showingNewCustomer = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(viewModel.customers) { customer in
                            Button {
                                editingCustomer = customer
                            } label: {
                                CustomerRow(customer: customer)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { offsets in
                            Task { await viewModel.deleteCustomers(at: offsets) }
                        }
                    }
                    .refreshable {
                        await viewModel.load()
                    }
                }
            }
            .navigationTitle("Customers")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewCustomer = true
                    } label: {
                        Label("New Customer", systemImage: "plus")
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
            .sheet(isPresented: $showingNewCustomer) {
                CustomerFormView(title: "New Customer") { request in
                    await viewModel.createCustomer(request)
                }
            }
            .sheet(item: $editingCustomer) { customer in
                CustomerFormView(title: "Edit Customer", customer: customer) { request in
                    await viewModel.updateCustomer(customer, request: request)
                }
            }
            .task {
                viewModel.configure(apiClient: appState.apiClient)
                await viewModel.load()
            }
        }
    }
}

private struct CustomerRow: View {
    let customer: Customer

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(customer.name)
                .font(.headline)
            HStack(spacing: 12) {
                if let phone = customer.phone {
                    Label(phone, systemImage: "phone")
                }
                if let email = customer.email {
                    Label(email, systemImage: "envelope")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if let address = customer.address {
                Text(address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct CustomerFormView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let customer: Customer?
    let onSave: (CustomerUpsertRequest) async -> Void

    @State private var name: String
    @State private var phone: String
    @State private var email: String
    @State private var address: String
    @State private var notes: String
    @State private var isSaving = false

    init(title: String, customer: Customer? = nil, onSave: @escaping (CustomerUpsertRequest) async -> Void) {
        self.title = title
        self.customer = customer
        self.onSave = onSave
        _name = State(initialValue: customer?.name ?? "")
        _phone = State(initialValue: customer?.phone ?? "")
        _email = State(initialValue: customer?.email ?? "")
        _address = State(initialValue: customer?.address ?? "")
        _notes = State(initialValue: customer?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Customer") {
                    TextField("Name", text: $name)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Address", text: $address, axis: .vertical)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving" : "Save") {
                        Task {
                            isSaving = true
                            await onSave(request)
                            isSaving = false
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
        }
    }

    private var request: CustomerUpsertRequest {
        CustomerUpsertRequest(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            phone: nilIfBlank(phone),
            email: nilIfBlank(email),
            address: nilIfBlank(address),
            notes: nilIfBlank(notes)
        )
    }

    private func nilIfBlank(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

@MainActor
final class CustomerListViewModel: ObservableObject {
    @Published private(set) var customers: [Customer] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var service: CustomerService?

    func configure(apiClient: APIClient) {
        if service == nil {
            service = CustomerService(apiClient: apiClient)
        }
    }

    func load() async {
        guard let service else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            customers = try await service.listCustomers()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createCustomer(_ request: CustomerUpsertRequest) async {
        guard let service else { return }
        do {
            let customer = try await service.createCustomer(request)
            customers.insert(customer, at: 0)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateCustomer(_ customer: Customer, request: CustomerUpsertRequest) async {
        guard let service else { return }
        do {
            let updated = try await service.updateCustomer(id: customer.id, request: request)
            if let index = customers.firstIndex(where: { $0.id == updated.id }) {
                customers[index] = updated
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteCustomers(at offsets: IndexSet) async {
        guard let service else { return }
        for index in offsets {
            let customer = customers[index]
            do {
                try await service.deleteCustomer(id: customer.id)
                customers.removeAll { $0.id == customer.id }
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct CustomerService {
    let apiClient: APIClient

    func listCustomers() async throws -> [Customer] {
        let response: ListResponse<Customer> = try await apiClient.get("customers")
        return response.items
    }

    func createCustomer(_ request: CustomerUpsertRequest) async throws -> Customer {
        try await apiClient.post("customers", body: request)
    }

    func updateCustomer(id: UUID, request: CustomerUpsertRequest) async throws -> Customer {
        try await apiClient.put("customers/\(id.uuidString)", body: request)
    }

    func deleteCustomer(id: UUID) async throws {
        try await apiClient.delete("customers/\(id.uuidString)")
    }
}
