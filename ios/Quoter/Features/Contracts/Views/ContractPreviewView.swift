import SwiftUI

struct ContractPreviewView: View {
    @State private var pdfURL: URL?
    @State private var showingShareSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Contract Preview")
                    .font(.largeTitle.weight(.bold))
                Spacer()
                Button("Generate Sample PDF") {
                    pdfURL = try? PDFGenerator().makeContractPDF(
                        title: "Quoter Contract",
                        lines: [
                            "Company information",
                            "Customer information",
                            "Quote snapshot",
                            "Payment and delivery terms",
                            "Drawing attachment placeholder"
                        ]
                    )
                }
                .buttonStyle(.borderedProminent)
            }

            if let pdfURL {
                PDFPreviewView(url: pdfURL)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Button("Share PDF") {
                    showingShareSheet = true
                }
                .buttonStyle(.bordered)
            } else {
                ContentUnavailableView {
                    Label("No PDF Generated", systemImage: "doc.richtext")
                } description: {
                    Text("Phase 9 will generate quote and contract PDFs from confirmed quote snapshots.")
                }
            }
        }
        .padding()
        .sheet(isPresented: $showingShareSheet) {
            if let pdfURL {
                ShareSheet(items: [pdfURL])
            }
        }
    }
}
