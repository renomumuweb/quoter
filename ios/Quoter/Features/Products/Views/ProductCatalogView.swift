import SwiftUI

struct ProductCatalogView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Product Catalog", systemImage: "shippingbox")
        } description: {
            Text("Phase 7 will load brands, categories, products, prices, and matcher recommendations from the API.")
        }
    }
}
