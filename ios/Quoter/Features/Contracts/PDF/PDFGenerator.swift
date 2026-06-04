import UIKit

struct PDFSection {
    var title: String
    var lines: [String]
}

struct PDFGenerator {
    func makeContractPDF(title: String, lines: [String], language: AppLanguage = AppLanguage.storedOrDefault) throws -> URL {
        let copy = PDFCopy(language: language)
        return try makePDF(
            filePrefix: title,
            title: title,
            subtitle: copy.contractSubtitle,
            sections: [PDFSection(title: copy.contractDetails, lines: lines)],
            signatureLines: [copy.customerSignature, copy.companySignature]
        )
    }

    func makeQuotePDF(title: String, lines: [String], language: AppLanguage = AppLanguage.storedOrDefault) throws -> URL {
        let copy = PDFCopy(language: language)
        return try makePDF(
            filePrefix: title,
            title: title,
            subtitle: copy.quoteSubtitle,
            sections: [PDFSection(title: copy.quoteDetails, lines: lines)],
            signatureLines: []
        )
    }

    private func makePDF(
        filePrefix: String,
        title: String,
        subtitle: String,
        sections: [PDFSection],
        signatureLines: [String]
    ) throws -> URL {
        let url = outputURL(filePrefix: filePrefix)
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let margin: CGFloat = 54
        let contentWidth = pageRect.width - margin * 2

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: title,
            kCGPDFContextCreator as String: "Quoter"
        ]

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        try renderer.writePDF(to: url) { context in
            context.beginPage()
            var y = margin

            draw(
                title,
                font: .systemFont(ofSize: 24, weight: .bold),
                color: .black,
                x: margin,
                y: &y,
                width: contentWidth,
                pageRect: pageRect,
                margin: margin,
                context: context
            )
            y += 6

            draw(
                subtitle,
                font: .systemFont(ofSize: 11, weight: .regular),
                color: .darkGray,
                x: margin,
                y: &y,
                width: contentWidth,
                pageRect: pageRect,
                margin: margin,
                context: context
            )
            y += 18

            for section in sections {
                draw(
                    section.title,
                    font: .systemFont(ofSize: 15, weight: .semibold),
                    color: .black,
                    x: margin,
                    y: &y,
                    width: contentWidth,
                    pageRect: pageRect,
                    margin: margin,
                    context: context
                )
                y += 4

                for line in section.lines {
                    draw(
                        line,
                        font: .systemFont(ofSize: 12, weight: .regular),
                        color: .black,
                        x: margin,
                        y: &y,
                        width: contentWidth,
                        pageRect: pageRect,
                        margin: margin,
                        context: context
                    )
                    y += 4
                }
                y += 12
            }

            if !signatureLines.isEmpty {
                if y > pageRect.height - margin - 120 {
                    context.beginPage()
                    y = margin
                }
                y = max(y, pageRect.height - margin - 90)
                for signature in signatureLines {
                    draw(
                        signature,
                        font: .systemFont(ofSize: 12, weight: .regular),
                        color: .black,
                        x: margin,
                        y: &y,
                        width: contentWidth,
                        pageRect: pageRect,
                        margin: margin,
                        context: context
                    )
                    y += 12
                }
            }
        }

        return url
    }

    private func draw(
        _ text: String,
        font: UIFont,
        color: UIColor,
        x: CGFloat,
        y: inout CGFloat,
        width: CGFloat,
        pageRect: CGRect,
        margin: CGFloat,
        context: UIGraphicsPDFRendererContext
    ) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.lineSpacing = 2

        let attributed = NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraphStyle
            ]
        )
        let measured = attributed.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).integral

        if y + measured.height > pageRect.height - margin {
            context.beginPage()
            y = margin
        }

        attributed.draw(
            with: CGRect(x: x, y: y, width: width, height: measured.height + 2),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        y += measured.height + 8
    }

    private func outputURL(filePrefix: String) -> URL {
        let safeName = filePrefix
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        let fileName = (safeName.isEmpty ? "quoter-document" : safeName) + "-\(UUID().uuidString.prefix(8))"
        return FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)
            .appendingPathExtension("pdf")
    }
}

private struct PDFCopy {
    let contractSubtitle: String
    let contractDetails: String
    let quoteSubtitle: String
    let quoteDetails: String
    let customerSignature: String
    let companySignature: String

    init(language: AppLanguage) {
        switch language {
        case .simplifiedChinese:
            contractSubtitle = "由 Quoter 生成的合同 PDF"
            contractDetails = "合同详情"
            quoteSubtitle = "由 Quoter 生成的报价 PDF"
            quoteDetails = "报价详情"
            customerSignature = "客户签名：__________________________"
            companySignature = "公司签名：__________________________"
        case .english, .french, .italian:
            contractSubtitle = "Contract PDF generated by Quoter"
            contractDetails = "Contract Details"
            quoteSubtitle = "Quote PDF generated by Quoter"
            quoteDetails = "Quote Details"
            customerSignature = "Customer Signature: __________________________"
            companySignature = "Company Signature: __________________________"
        }
    }
}
