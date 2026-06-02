import Foundation

struct Customer: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var phone: String?
    var email: String?
    var address: String?
    var notes: String?
    var status: String?
    var createdAt: Date?
    var updatedAt: Date?
}

struct CustomerUpsertRequest: Encodable {
    var name: String
    var phone: String?
    var email: String?
    var address: String?
    var notes: String?
}
