import Foundation
import MessageUI
import SwiftUI

struct PDFMailComposer: UIViewControllerRepresentable {
    let pdfURL: URL
    let recipient: String
    let subject: String
    let body: String
    let onFinish: (Result<MFMailComposeResult, Error>) -> Void

    static var canSendMail: Bool {
        MFMailComposeViewController.canSendMail()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients([recipient])
        controller.setSubject(subject)
        controller.setMessageBody(body, isHTML: false)

        if let data = try? Data(contentsOf: pdfURL) {
            controller.addAttachmentData(
                data,
                mimeType: "application/pdf",
                fileName: pdfURL.lastPathComponent
            )
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onFinish: (Result<MFMailComposeResult, Error>) -> Void

        init(onFinish: @escaping (Result<MFMailComposeResult, Error>) -> Void) {
            self.onFinish = onFinish
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            controller.dismiss(animated: true)
            if let error {
                onFinish(.failure(error))
            } else {
                onFinish(.success(result))
            }
        }
    }
}
