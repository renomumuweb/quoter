import Foundation

struct Product: Codable, Identifiable, Hashable {
    let id: UUID
    var brand: String
    var category: String
    var name: String
    var sku: String
    var size: String?
    var color: String?
    var material: String?
    var unit: String
    var description: String?
    var imageURL: URL?
    var active: Bool
    var isService: Bool
}

struct ProductPrice: Codable, Identifiable, Hashable {
    let id: UUID
    let productID: UUID
    let currency: String
    let unitPrice: Decimal
    let effectiveFrom: Date
    let effectiveTo: Date?

    func isEffective(on date: Date) -> Bool {
        effectiveFrom <= date && (effectiveTo == nil || effectiveTo! >= date)
    }
}

struct ProjectContext: Codable, Hashable {
    var roomType: String
}

struct RecentProduct: Codable, Hashable {
    var productID: UUID
    var usedAt: Date
}
