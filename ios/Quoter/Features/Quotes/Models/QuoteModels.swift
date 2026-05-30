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

struct QuoteItemPreview: Identifiable, Hashable {
    let id = UUID()
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
}

struct UnboundQuoteWarning: Identifiable, Hashable {
    let id = UUID()
    let sourceObjectID: UUID
    let objectType: String
    let message: String
}

struct QuotePreview: Hashable {
    let items: [QuoteItemPreview]
    let warnings: [UnboundQuoteWarning]
    let subtotal: Decimal
    let discountTotal: Decimal
    let taxTotal: Decimal
    let total: Decimal
}
