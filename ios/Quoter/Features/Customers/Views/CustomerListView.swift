import SwiftUI

struct CustomerListView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Customers", systemImage: "person.2")
        } description: {
            Text("Phase 5 will add customer CRUD against the self-hosted API.")
        } actions: {
            Button("New Customer") {}
                .buttonStyle(.borderedProminent)
                .disabled(true)
        }
        .navigationTitle("Customers")
    }
}
