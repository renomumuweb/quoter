import Foundation

struct EstimateTemplateService {
    let apiClient: APIClient

    func listTemplates() async throws -> [EstimateTemplate] {
        let response: ListResponse<EstimateTemplate> = try await apiClient.get("estimate-templates")
        return response.items
    }

    func saveTemplate(_ template: EstimateTemplate, name: String, projectID: UUID?) async throws -> EstimateTemplate {
        var request = template.reusableCopy(named: name)
        request.projectID = projectID
        return try await apiClient.post("estimate-templates", body: request)
    }

    func updateTemplate(_ template: EstimateTemplate) async throws -> EstimateTemplate {
        try await apiClient.put("estimate-templates/\(template.id.uuidString)", body: template)
    }

    func deleteTemplate(id: UUID) async throws {
        try await apiClient.delete("estimate-templates/\(id.uuidString)")
    }
}
