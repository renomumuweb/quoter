import CoreGraphics
import Foundation

struct DrawingObject: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var objectType: String
    var productID: UUID?
    var serviceID: UUID?
    var categoryID: UUID?
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat
    var rotation: Double
    var quantity: Decimal
    var unit: String
    var discountAmount: Decimal
    var installationFee: Decimal
    var notes: String
    var isQuoteEnabled: Bool
    var isContractVisible: Bool
}

struct DrawingAnnotation: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var annotationType: String
    var text: String
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat
    var rotation: Double
    var linkedObjectID: UUID?
    var linkedProductID: UUID?
    var linkedQuoteItemID: UUID?
    var exportToPDF: Bool
    var showInContract: Bool
}

extension DrawingObject {
    static let preview = DrawingObject(
        objectType: "vanity",
        x: 0.42,
        y: 0.38,
        width: 0.2,
        height: 0.12,
        rotation: 0,
        quantity: 1,
        unit: "each",
        discountAmount: 0,
        installationFee: 150,
        notes: "60 inch vanity wall",
        isQuoteEnabled: true,
        isContractVisible: true
    )
}

extension DrawingAnnotation {
    static let preview = DrawingAnnotation(
        annotationType: "dimension",
        text: "60 inch white vanity",
        x: 0.4,
        y: 0.28,
        width: 0.24,
        height: 0.06,
        rotation: 0,
        exportToPDF: true,
        showInContract: true
    )
}
