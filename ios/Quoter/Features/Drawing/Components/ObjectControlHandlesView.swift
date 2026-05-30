import SwiftUI

struct ObjectControlHandlesView: View {
    var body: some View {
        GeometryReader { proxy in
            ForEach(handlePoints(in: proxy.size), id: \.self) { point in
                Circle()
                    .fill(Color.white)
                    .stroke(Color.blue, lineWidth: 2)
                    .frame(width: 12, height: 12)
                    .position(point)
            }
        }
        .allowsHitTesting(false)
    }

    private func handlePoints(in size: CGSize) -> [CGPoint] {
        [
            CGPoint(x: 0, y: 0),
            CGPoint(x: size.width, y: 0),
            CGPoint(x: 0, y: size.height),
            CGPoint(x: size.width, y: size.height)
        ]
    }
}
