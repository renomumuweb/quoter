import SwiftUI

struct QuotePreviewView: View {
    private let preview = QuotePreview(
        items: [],
        warnings: [
            UnboundQuoteWarning(
                sourceObjectID: UUID(),
                objectType: "vanity",
                message: "Phase 8 will generate quote items from structured drawing objects."
            )
        ],
        subtotal: 0,
        discountTotal: 0,
        taxTotal: 0,
        total: 0
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Quote Preview")
                .font(.largeTitle.weight(.bold))
            ForEach(preview.warnings) { warning in
                Label(warning.message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
            Spacer()
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Subtotal", value: DecimalFormatter.currency(preview.subtotal))
                LabeledContent("Discount", value: DecimalFormatter.currency(preview.discountTotal))
                LabeledContent("Tax", value: DecimalFormatter.currency(preview.taxTotal))
                LabeledContent("Total", value: DecimalFormatter.currency(preview.total))
                    .font(.headline)
            }
        }
        .padding()
        .navigationTitle("Quote")
    }
}
