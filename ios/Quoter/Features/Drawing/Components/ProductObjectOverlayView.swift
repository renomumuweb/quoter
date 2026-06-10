import SwiftUI

struct ProductObjectOverlayView: View {
    let object: DrawingObject
    let isSelected: Bool
    let productName: String?
    let canvasScale: CGFloat
    let canEdit: Bool
    let onTap: () -> Void
    let onMove: (DrawingObject) -> Void
    let onResize: (DrawingObject) -> Void
    let onCommit: (DrawingObject) -> Void

    @State private var dragStart: DrawingObject?
    @State private var resizeStart: DrawingObject?
    @State private var pendingObject: DrawingObject?

    var body: some View {
        GeometryReader { proxy in
            let rect = CanvasCoordinateMapper.rect(for: object, in: proxy.size)
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.blue : Color.blue.opacity(0.55), lineWidth: isSelected ? 3 : 1)
                    }
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
                    .padding(4)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                if isSelected {
                    ObjectControlHandlesView()
                }
            }
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .rotationEffect(.degrees(object.rotation))
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .gesture(moveGesture(canvasSize: proxy.size))
            .simultaneousGesture(resizeGesture())
        }
    }

    private var label: String {
        if let productName {
            return productName
        }
        let objectType = AppLanguage.localizedKnownSystemString(object.objectType)
        return object.productID == nil ? "\(objectType)\n\(AppLanguage.localizedString("Unbound"))" : objectType
    }

    private func moveGesture(canvasSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                guard canEdit else { return }
                if dragStart == nil {
                    dragStart = object
                }
                guard let start = dragStart else { return }
                let safeScale = max(canvasScale, 0.1)
                var updated = object
                updated.x = clamped(start.x + value.translation.width / (canvasSize.width * safeScale))
                updated.y = clamped(start.y + value.translation.height / (canvasSize.height * safeScale))
                pendingObject = updated
                onMove(updated)
            }
            .onEnded { _ in
                if let pendingObject {
                    onCommit(pendingObject)
                }
                pendingObject = nil
                dragStart = nil
            }
    }

    private func resizeGesture() -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                guard canEdit, isSelected else { return }
                if resizeStart == nil {
                    resizeStart = object
                }
                guard let start = resizeStart else { return }
                var updated = object
                updated.width = clamped(start.width * value, min: 0.04, max: 0.9)
                updated.height = clamped(start.height * value, min: 0.04, max: 0.9)
                pendingObject = updated
                onResize(updated)
            }
            .onEnded { _ in
                if let pendingObject {
                    onCommit(pendingObject)
                }
                pendingObject = nil
                resizeStart = nil
            }
    }

    private func clamped(_ value: CGFloat, min minimum: CGFloat = 0, max maximum: CGFloat = 1) -> CGFloat {
        Swift.min(Swift.max(value, minimum), maximum)
    }
}
