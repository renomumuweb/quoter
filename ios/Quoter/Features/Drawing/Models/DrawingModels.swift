import CoreGraphics
import Foundation

struct DrawingObject: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var projectID: UUID?
    var drawingID: UUID?
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
    var status: String?
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case projectID = "projectId"
        case drawingID = "drawingId"
        case objectType
        case productID = "productId"
        case serviceID = "serviceId"
        case categoryID = "categoryId"
        case x
        case y
        case width
        case height
        case rotation
        case quantity
        case unit
        case discountAmount
        case installationFee
        case notes
        case isQuoteEnabled
        case isContractVisible
        case status
        case createdAt
        case updatedAt
    }
}

struct DrawingAnnotation: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var projectID: UUID?
    var drawingID: UUID?
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
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case projectID = "projectId"
        case drawingID = "drawingId"
        case annotationType
        case text
        case x
        case y
        case width
        case height
        case rotation
        case linkedObjectID = "linkedObjectId"
        case linkedProductID = "linkedProductId"
        case linkedQuoteItemID = "linkedQuoteItemId"
        case exportToPDF = "exportToPdf"
        case showInContract
        case createdAt
        case updatedAt
    }
}

struct DrawingRecord: Codable, Identifiable, Hashable {
    let id: UUID
    let projectID: UUID
    var drawingFileAssetID: UUID?
    var previewFileAssetID: UUID?
    var canvasWidth: Double
    var canvasHeight: Double
    var status: String
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case projectID = "projectId"
        case drawingFileAssetID = "drawingFileAssetId"
        case previewFileAssetID = "previewFileAssetId"
        case canvasWidth
        case canvasHeight
        case status
        case createdAt
        case updatedAt
    }
}

struct DrawingResponse: Codable, Hashable {
    var drawing: DrawingRecord
    var objects: [DrawingObject]
    var annotations: [DrawingAnnotation]
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
