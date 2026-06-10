import Foundation

struct EstimateTemplateService {
    let apiClient: APIClient

    func getProjectEstimate(projectID: UUID) async throws -> EstimateTemplate {
        try await apiClient.get("projects/\(projectID.uuidString)/estimate")
    }

    func saveProjectEstimate(_ estimate: EstimateTemplate, projectID: UUID) async throws -> EstimateTemplate {
        var request = estimate
        request.projectID = projectID
        return try await apiClient.put("projects/\(projectID.uuidString)/estimate", body: request)
    }

    func applyTemplate(projectID: UUID, templateID: UUID) async throws -> EstimateTemplate {
        try await apiClient.post(
            "projects/\(projectID.uuidString)/estimate/apply-template",
            body: ApplyEstimateTemplateRequest(templateID: templateID)
        )
    }

    func importDrawingItems(projectID: UUID) async throws -> EstimateTemplate {
        try await apiClient.post("projects/\(projectID.uuidString)/estimate/import-drawing-items", body: EmptyRequest())
    }

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

private struct ApplyEstimateTemplateRequest: Encodable {
    let templateID: UUID

    enum CodingKeys: String, CodingKey {
        case templateID = "templateId"
    }
}
