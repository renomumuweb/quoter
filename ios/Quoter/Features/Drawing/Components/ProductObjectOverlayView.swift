import SwiftUI

struct ProductObjectOverlayView: View {
    let object: DrawingObject
    let isSelected: Bool

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
                if isSelected {
                    ObjectControlHandlesView()
                }
            }
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .rotationEffect(.degrees(object.rotation))
        }
    }

    private var label: String {
        object.productID == nil ? "\(object.objectType.capitalized)\nUnbound" : object.objectType.capitalized
    }
}
