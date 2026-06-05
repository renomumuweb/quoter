import Foundation

struct EstimateStore {
    private let draftStore = LocalDraftStore()
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init() {
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func loadProjectEstimate(projectID: UUID) throws -> EstimateTemplate? {
        guard let data = try draftStore.load(name: projectFileName(projectID)) else { return nil }
        return try decoder.decode(EstimateTemplate.self, from: data)
    }

    func saveProjectEstimate(_ estimate: EstimateTemplate, projectID: UUID) throws {
        var saved = estimate
        saved.projectID = projectID
        saved.updatedAt = Date()
        let data = try encoder.encode(saved)
        try draftStore.save(data: data, name: projectFileName(projectID))
    }

    func deleteProjectEstimate(projectID: UUID) throws {
        try draftStore.delete(name: projectFileName(projectID))
    }

    func loadReusableTemplates() throws -> [EstimateTemplate] {
        guard let data = try draftStore.load(name: reusableTemplatesFileName) else { return [] }
        return try decoder.decode([EstimateTemplate].self, from: data)
    }

    func saveReusableTemplate(_ estimate: EstimateTemplate, name: String) throws {
        var templates = try loadReusableTemplates()
        let reusable = estimate.reusableCopy(named: name)
        templates.removeAll { $0.name.caseInsensitiveCompare(name) == .orderedSame }
        templates.insert(reusable, at: 0)
        let data = try encoder.encode(templates)
        try draftStore.save(data: data, name: reusableTemplatesFileName)
    }

    private var reusableTemplatesFileName: String {
        "estimate_templates.json"
    }

    private func projectFileName(_ projectID: UUID) -> String {
        "estimate_\(projectID.uuidString).json"
    }
}
