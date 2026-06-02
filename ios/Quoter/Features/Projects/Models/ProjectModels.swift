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
