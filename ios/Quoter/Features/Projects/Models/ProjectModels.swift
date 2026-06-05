import Foundation

struct Project: Codable, Identifiable, Hashable {
    let id: UUID
    var customerID: UUID
    var customerName: String?
    var title: String
    var roomType: String
    var status: String
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case customerID = "customerId"
        case customerName
        case title
        case roomType
        case status
        case createdAt
        case updatedAt
    }
}

struct ProjectUpsertRequest: Encodable {
    var customerID: UUID
    var title: String
    var roomType: String
    var status: String

    enum CodingKeys: String, CodingKey {
        case customerID = "customerId"
        case title
        case roomType
        case status
    }
}

struct ProjectServiceScope: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String
}

extension Project {
    static let serviceScopes: [ProjectServiceScope] = [
        ProjectServiceScope(id: "kitchen", title: "Kitchen", icon: "cooktop"),
        ProjectServiceScope(id: "bathroom", title: "Bathroom", icon: "shower"),
        ProjectServiceScope(id: "whole_home", title: "Whole Home", icon: "house"),
        ProjectServiceScope(id: "condo", title: "Condo", icon: "building.2"),
        ProjectServiceScope(id: "basement", title: "Basement", icon: "stairs"),
        ProjectServiceScope(id: "room", title: "Room", icon: "bed.double"),
        ProjectServiceScope(id: "flooring", title: "Flooring", icon: "square.grid.3x3"),
        ProjectServiceScope(id: "doors_windows", title: "Doors/Windows", icon: "door.left.hand.open"),
        ProjectServiceScope(id: "custom", title: "Custom", icon: "slider.horizontal.3"),
        ProjectServiceScope(id: "countertops", title: "Countertops", icon: "rectangle.center.inset.filled")
    ]

    static func serviceScopeTitle(_ rawValue: String) -> String {
        let ids = rawValue
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !ids.isEmpty else { return "Other" }

        let names = ids.map { id in
            serviceScopes.first { $0.id == id }?.title ?? id.replacingOccurrences(of: "_", with: " ").capitalized
        }
        return names.joined(separator: ", ")
    }
}
