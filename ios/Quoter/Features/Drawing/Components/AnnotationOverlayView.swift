import SwiftUI

struct AnnotationOverlayView: View {
    let annotation: DrawingAnnotation
    let isSelected: Bool
    let canvasScale: CGFloat
    let canEdit: Bool
    let onTap: () -> Void
    let onMove: (DrawingAnnotation) -> Void
    let onCommit: (DrawingAnnotation) -> Void

    @State private var dragStart: DrawingAnnotation?
    @State private var pendingAnnotation: DrawingAnnotation?

    var body: some View {
        GeometryReader { proxy in
            let rect = CanvasCoordinateMapper.rect(for: annotation, in: proxy.size)
            Text(annotation.text)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.yellow.opacity(0.28), in: RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.orange : Color.orange.opacity(0.7), lineWidth: isSelected ? 2 : 1)
                }
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .rotationEffect(.degrees(annotation.rotation))
                .contentShape(Rectangle())
                .onTapGesture(perform: onTap)
                .gesture(moveGesture(canvasSize: proxy.size))
        }
    }

    private func moveGesture(canvasSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                guard canEdit else { return }
                if dragStart == nil {
                    dragStart = annotation
                }
                guard let start = dragStart else { return }
                let safeScale = max(canvasScale, 0.1)
                var updated = annotation
                updated.x = clamped(start.x + value.translation.width / (canvasSize.width * safeScale))
                updated.y = clamped(start.y + value.translation.height / (canvasSize.height * safeScale))
                pendingAnnotation = updated
                onMove(updated)
            }
            .onEnded { _ in
                if let pendingAnnotation {
                    onCommit(pendingAnnotation)
                }
                pendingAnnotation = nil
                dragStart = nil
            }
    }

    private func clamped(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }
}
