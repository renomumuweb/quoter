import CoreGraphics

enum CanvasCoordinateMapper {
    static func rect(for object: DrawingObject, in size: CGSize) -> CGRect {
        CGRect(
            x: object.x * size.width,
            y: object.y * size.height,
            width: object.width * size.width,
            height: object.height * size.height
        )
    }

    static func rect(for annotation: DrawingAnnotation, in size: CGSize) -> CGRect {
        CGRect(
            x: annotation.x * size.width,
            y: annotation.y * size.height,
            width: annotation.width * size.width,
            height: annotation.height * size.height
        )
    }

    static func relativeRect(from rect: CGRect, in size: CGSize) -> CGRect {
        guard size.width > 0, size.height > 0 else { return .zero }
        return CGRect(
            x: rect.minX / size.width,
            y: rect.minY / size.height,
            width: rect.width / size.width,
            height: rect.height / size.height
        )
    }
}
