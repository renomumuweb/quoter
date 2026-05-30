import UIKit

struct PDFGenerator {
    func makeContractPDF(title: String, lines: [String]) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(title.replacingOccurrences(of: " ", with: "-"))
            .appendingPathExtension("pdf")

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        try renderer.writePDF(to: url) { context in
            context.beginPage()

            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24)
            ]
            title.draw(at: CGPoint(x: 54, y: 54), withAttributes: titleAttributes)

            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12)
            ]
            var y: CGFloat = 100
            for line in lines {
                line.draw(at: CGPoint(x: 54, y: y), withAttributes: bodyAttributes)
                y += 22
            }

            "Customer Signature: __________________________".draw(
                at: CGPoint(x: 54, y: 690),
                withAttributes: bodyAttributes
            )
            "Company Signature: __________________________".draw(
                at: CGPoint(x: 54, y: 725),
                withAttributes: bodyAttributes
            )
        }

        return url
    }
}
