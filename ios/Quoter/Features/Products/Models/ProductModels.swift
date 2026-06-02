import Foundation

struct Product: Codable, Identifiable, Hashable {
    let id: UUID
    var brandID: UUID?
    var brand: String
    var categoryID: UUID?
    var category: String
    var categoryKind: String?
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
    var currentPriceID: UUID?
    var currency: String?
    var currentPrice: Decimal?

    enum CodingKeys: String, CodingKey {
        case id
        case brandID = "brandId"
        case brand
        case categoryID = "categoryId"
        case category
        case categoryKind
        case name
        case sku
        case size
        case color
        case material
        case unit
        case description
        case imageURL = "imageUrl"
        case active
        case isService
        case currentPriceID = "currentPriceId"
        case currency
        case currentPrice
    }
}

struct ProductUpsertRequest: Encodable {
    var brandID: UUID?
    var categoryID: UUID
    var name: String
    var sku: String
    var size: String?
    var color: String?
    var material: String?
    var unit: String
    var description: String?
    var imageURL: String?
    var active: Bool
    var isService: Bool
    var currentPrice: Decimal?
    var currency: String

    enum CodingKeys: String, CodingKey {
        case brandID = "brandId"
        case categoryID = "categoryId"
        case name
        case sku
        case size
        case color
        case material
        case unit
        case description
        case imageURL = "imageUrl"
        case active
        case isService
        case currentPrice
        case currency
    }
}

struct ProductBrand: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var status: String?
}

struct ProductCategory: Codable, Identifiable, Hashable {
    let id: UUID
    var parentID: UUID?
    var name: String
    var kind: String
    var status: String?

    enum CodingKeys: String, CodingKey {
        case id
        case parentID = "parentId"
        case name
        case kind
        case status
    }
}

struct BrandUpsertRequest: Encodable {
    var name: String
}

struct ProductCategoryUpsertRequest: Encodable {
    var parentID: UUID?
    var name: String
    var kind: String

    enum CodingKeys: String, CodingKey {
        case parentID = "parentId"
        case name
        case kind
    }
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
