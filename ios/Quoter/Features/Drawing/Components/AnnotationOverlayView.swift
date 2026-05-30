import SwiftUI

struct AnnotationOverlayView: View {
    let annotation: DrawingAnnotation

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
                        .stroke(Color.orange.opacity(0.7), lineWidth: 1)
                }
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .rotationEffect(.degrees(annotation.rotation))
        }
    }
}
