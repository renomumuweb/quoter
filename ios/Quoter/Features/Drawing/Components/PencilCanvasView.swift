import PencilKit
import SwiftUI

struct PencilCanvasView: UIViewRepresentable {
    @Binding var drawingData: Data

    func makeCoordinator() -> Coordinator {
        Coordinator(drawingData: $drawingData)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.delegate = context.coordinator
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.pen, color: .label, width: 4)
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        guard !drawingData.isEmpty,
              uiView.drawing.dataRepresentation() != drawingData,
              let drawing = try? PKDrawing(data: drawingData) else {
            return
        }
        uiView.drawing = drawing
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        @Binding private var drawingData: Data

        init(drawingData: Binding<Data>) {
            _drawingData = drawingData
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            drawingData = canvasView.drawing.dataRepresentation()
        }
    }
}
