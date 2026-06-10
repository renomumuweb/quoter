import SwiftUI

struct ProjectListView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ProjectListViewModel()
    @State private var showingNewProject = false
    @State private var editingProject: Project?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.projects.isEmpty {
                    ProgressView("Loading projects")
                } else if viewModel.projects.isEmpty {
                    ContentUnavailableView {
                        Label("No Projects", systemImage: "folder")
                    } description: {
                        Text(LocalizedStringKey(viewModel.customers.isEmpty ? "Create a customer first, then start a project." : "Create a project to open drawing and estimate tools."))
                    } actions: {
                        Button("New Project") {
                            showingNewProject = true
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.customers.isEmpty)
                    }
                } else {
                    List {
                        ForEach(viewModel.projects) { project in
                            NavigationLink {
                                ProjectWorkspaceView(project: project)
                            } label: {
                                ProjectRow(project: project)
                                    .swipeActions(edge: .leading) {
                                        Button("Edit") {
                                            editingProject = project
                                        }
                                        .tint(.blue)
                                    }
                            }
                        }
                        .onDelete { offsets in
                            Task { await viewModel.deleteProjects(at: offsets) }
                        }
                    }
                    .refreshable {
                        await viewModel.load()
                    }
                }
            }
            .navigationTitle("Projects")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewProject = true
                    } label: {
                        Label("New Project", systemImage: "plus")
                    }
                    .disabled(viewModel.customers.isEmpty)
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
            .sheet(isPresented: $showingNewProject) {
                ProjectFormView(title: "New Project", customers: viewModel.customers) { request in
                    await viewModel.createProject(request)
                }
            }
            .sheet(item: $editingProject) { project in
                ProjectFormView(title: "Edit Project", project: project, customers: viewModel.customers) { request in
                    await viewModel.updateProject(project, request: request)
                }
            }
            .task {
                viewModel.configure(apiClient: appState.apiClient)
                await viewModel.load()
            }
        }
    }
}

private struct ProjectRow: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(project.title)
                    .font(.headline)
                Spacer()
                Text(AppLanguage.localizedStatus(project.status))
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.12), in: Capsule())
            }
            HStack(spacing: 12) {
                Label(project.customerName ?? AppLanguage.localizedString("Customer"), systemImage: "person")
                Label(Project.serviceScopeTitle(project.roomType), systemImage: "square.grid.2x2")
                HStack(spacing: 2) {
                    Text("Updated")
                    Text(project.updatedAt, style: .date)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct ProjectFormView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let project: Project?
    let customers: [Customer]
    let onSave: (ProjectUpsertRequest) async -> Void

    @State private var customerID: UUID
    @State private var projectTitle: String
    @State private var selectedScopes: Set<String>
    @State private var status: String
    @State private var isSaving = false

    init(
        title: String,
        project: Project? = nil,
        customers: [Customer],
        onSave: @escaping (ProjectUpsertRequest) async -> Void
    ) {
        self.title = title
        self.project = project
        self.customers = customers
        self.onSave = onSave
        _customerID = State(initialValue: project?.customerID ?? customers.first?.id ?? UUID())
        _projectTitle = State(initialValue: project?.title ?? "")
        _selectedScopes = State(initialValue: ProjectFormView.scopes(from: project?.roomType ?? "bathroom"))
        _status = State(initialValue: project?.status ?? "draft")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Project") {
                    Picker("Customer", selection: $customerID) {
                        ForEach(customers) { customer in
                            Text(customer.name).tag(customer.id)
                        }
                    }
                    TextField("Title", text: $projectTitle)
                }

                Section("Service Areas") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                        ForEach(Project.serviceScopes, id: \.id) { scope in
                            Button {
                                toggle(scope.id)
                            } label: {
                                Label(LocalizedStringKey(scope.title), systemImage: scope.icon)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.bordered)
                            .tint(selectedScopes.contains(scope.id) ? Color.blue : Color.secondary)
                        }
                    }
                }

                Section("Status") {
                    Picker("Status", selection: $status) {
                        Text("Draft").tag("draft")
                        Text("Quoted").tag("quoted")
                        Text("Approved").tag("approved")
                        Text("Completed").tag("completed")
                    }
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
                    .disabled(customers.isEmpty || projectTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
        }
    }

    private var request: ProjectUpsertRequest {
        ProjectUpsertRequest(
            customerID: customerID,
            title: projectTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            roomType: selectedScopes.isEmpty ? "other" : selectedScopes.sorted().joined(separator: ","),
            status: status
        )
    }

    private func toggle(_ scope: String) {
        if selectedScopes.contains(scope) {
            selectedScopes.remove(scope)
        } else {
            selectedScopes.insert(scope)
        }
    }

    private static func scopes(from rawValue: String) -> Set<String> {
        let scopes = rawValue
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Set(scopes.isEmpty ? ["bathroom"] : scopes)
    }
}

@MainActor
final class ProjectListViewModel: ObservableObject {
    @Published private(set) var projects: [Project] = []
    @Published private(set) var customers: [Customer] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var projectService: ProjectService?
    private var customerService: CustomerService?

    func configure(apiClient: APIClient) {
        if projectService == nil {
            projectService = ProjectService(apiClient: apiClient)
            customerService = CustomerService(apiClient: apiClient)
        }
    }

    func load() async {
        guard let projectService, let customerService else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            async let loadedCustomers = customerService.listCustomers()
            async let loadedProjects = projectService.listProjects()
            customers = try await loadedCustomers
            projects = try await loadedProjects
            errorMessage = nil
        } catch {
            errorMessage = AppLanguage.localizedErrorDescription(error)
        }
    }

    func createProject(_ request: ProjectUpsertRequest) async {
        guard let projectService else { return }
        do {
            let project = try await projectService.createProject(request)
            projects.insert(project, at: 0)
            errorMessage = nil
        } catch {
            errorMessage = AppLanguage.localizedErrorDescription(error)
        }
    }

    func updateProject(_ project: Project, request: ProjectUpsertRequest) async {
        guard let projectService else { return }
        do {
            let updated = try await projectService.updateProject(id: project.id, request: request)
            if let index = projects.firstIndex(where: { $0.id == updated.id }) {
                projects[index] = updated
            }
            errorMessage = nil
        } catch {
            errorMessage = AppLanguage.localizedErrorDescription(error)
        }
    }

    func deleteProjects(at offsets: IndexSet) async {
        guard let projectService else { return }
        for index in offsets {
            let project = projects[index]
            do {
                try await projectService.deleteProject(id: project.id)
                projects.removeAll { $0.id == project.id }
                errorMessage = nil
            } catch {
                errorMessage = AppLanguage.localizedErrorDescription(error)
            }
        }
    }
}

struct ProjectService {
    let apiClient: APIClient

    func listProjects() async throws -> [Project] {
        let response: ListResponse<Project> = try await apiClient.get("projects")
        return response.items
    }

    func createProject(_ request: ProjectUpsertRequest) async throws -> Project {
        try await apiClient.post("projects", body: request)
    }

    func updateProject(id: UUID, request: ProjectUpsertRequest) async throws -> Project {
        try await apiClient.put("projects/\(id.uuidString)", body: request)
    }

    func deleteProject(id: UUID) async throws {
        try await apiClient.delete("projects/\(id.uuidString)")
    }
}
