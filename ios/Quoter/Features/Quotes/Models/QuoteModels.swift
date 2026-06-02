import Foundation

struct QuoteProduct: Hashable {
    let id: UUID
    let name: String
    let sku: String
    let brand: String
    let category: String
    let unit: String
}

struct QuotePrice: Hashable {
    let productID: UUID
    let unitPrice: Decimal
    let effectiveFrom: Date
    let effectiveTo: Date?

    func isEffective(on date: Date) -> Bool {
        effectiveFrom <= date && (effectiveTo == nil || effectiveTo! >= date)
    }
}

struct QuoteItemPreview: Identifiable, Codable, Hashable {
    var serverID: UUID?
    var id: UUID { serverID ?? sourceObjectID }
    let productID: UUID
    let sourceObjectID: UUID
    let productNameSnapshot: String
    let skuSnapshot: String
    let brandSnapshot: String
    let categorySnapshot: String
    let unitSnapshot: String
    let unitPriceSnapshot: Decimal
    let quantity: Decimal
    let discountAmount: Decimal
    let installationFee: Decimal
    let lineTotal: Decimal
    let notesSnapshot: String
    let isContractVisible: Bool
    let sortOrder: Int?

    enum CodingKeys: String, CodingKey {
        case serverID = "id"
        case productID = "productId"
        case sourceObjectID = "sourceObjectId"
        case productNameSnapshot
        case skuSnapshot
        case brandSnapshot
        case categorySnapshot
        case unitSnapshot
        case unitPriceSnapshot
        case quantity
        case discountAmount
        case installationFee
        case lineTotal
        case notesSnapshot
        case isContractVisible
        case sortOrder
    }

    init(
        serverID: UUID? = nil,
        productID: UUID,
        sourceObjectID: UUID,
        productNameSnapshot: String,
        skuSnapshot: String,
        brandSnapshot: String,
        categorySnapshot: String,
        unitSnapshot: String,
        unitPriceSnapshot: Decimal,
        quantity: Decimal,
        discountAmount: Decimal,
        installationFee: Decimal,
        lineTotal: Decimal,
        notesSnapshot: String,
        isContractVisible: Bool,
        sortOrder: Int? = nil
    ) {
        self.serverID = serverID
        self.productID = productID
        self.sourceObjectID = sourceObjectID
        self.productNameSnapshot = productNameSnapshot
        self.skuSnapshot = skuSnapshot
        self.brandSnapshot = brandSnapshot
        self.categorySnapshot = categorySnapshot
        self.unitSnapshot = unitSnapshot
        self.unitPriceSnapshot = unitPriceSnapshot
        self.quantity = quantity
        self.discountAmount = discountAmount
        self.installationFee = installationFee
        self.lineTotal = lineTotal
        self.notesSnapshot = notesSnapshot
        self.isContractVisible = isContractVisible
        self.sortOrder = sortOrder
    }
}

struct UnboundQuoteWarning: Identifiable, Codable, Hashable {
    var id: UUID { sourceObjectID }
    let sourceObjectID: UUID
    let objectType: String
    let message: String

    enum CodingKeys: String, CodingKey {
        case sourceObjectID = "sourceObjectId"
        case objectType
        case message
    }
}

struct QuotePreview: Codable, Hashable {
    var customerID: UUID? = nil
    var customerName: String? = nil
    var projectID: UUID? = nil
    var projectTitle: String? = nil
    var drawingID: UUID? = nil
    let items: [QuoteItemPreview]
    let warnings: [UnboundQuoteWarning]
    var currency: String? = nil
    let subtotal: Decimal
    let discountTotal: Decimal
    var taxRate: Decimal? = nil
    let taxTotal: Decimal
    let total: Decimal

    enum CodingKeys: String, CodingKey {
        case customerID = "customerId"
        case customerName
        case projectID = "projectId"
        case projectTitle
        case drawingID = "drawingId"
        case items
        case warnings
        case currency
        case subtotal
        case discountTotal
        case taxRate
        case taxTotal
        case total
    }
}

struct Quote: Codable, Identifiable, Hashable {
    let id: UUID
    var customerID: UUID
    var projectID: UUID
    var drawingID: UUID?
    var quoteNumber: String
    var status: String
    var currency: String
    var subtotal: Decimal
    var discountTotal: Decimal
    var taxRate: Decimal
    var taxTotal: Decimal
    var total: Decimal
    var items: [QuoteItemPreview]
    var warnings: [UnboundQuoteWarning]?
    var confirmedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case customerID = "customerId"
        case projectID = "projectId"
        case drawingID = "drawingId"
        case quoteNumber
        case status
        case currency
        case subtotal
        case discountTotal
        case taxRate
        case taxTotal
        case total
        case items
        case warnings
        case confirmedAt
        case createdAt
        case updatedAt
    }
}
