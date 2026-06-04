import PDFKit
import SwiftUI

struct PDFPreviewView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(url: url)
        context.coordinator.loadedURL = url
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        guard context.coordinator.loadedURL != url else { return }
        uiView.document = PDFDocument(url: url)
        context.coordinator.loadedURL = url
    }

    static func dismantleUIView(_ uiView: PDFView, coordinator: Coordinator) {
        uiView.document = nil
        coordinator.loadedURL = nil
    }

    final class Coordinator {
        var loadedURL: URL?
    }
}
