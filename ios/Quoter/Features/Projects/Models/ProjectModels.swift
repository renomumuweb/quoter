import Foundation

struct Project: Codable, Identifiable, Hashable {
    let id: UUID
    var customerID: UUID
    var title: String
    var roomType: String
    var status: String
    var createdAt: Date
    var updatedAt: Date
}
