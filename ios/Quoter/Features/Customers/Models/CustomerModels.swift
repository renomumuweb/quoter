import Foundation

struct Customer: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var phone: String?
    var email: String?
    var address: String?
    var notes: String?
}
