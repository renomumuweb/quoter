import Foundation

struct PaginatedResponse<Item: Codable>: Codable {
    let items: [Item]
    let page: Int
    let perPage: Int
    let total: Int
}
