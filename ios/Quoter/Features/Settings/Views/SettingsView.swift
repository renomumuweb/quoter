import SwiftUI

struct SettingsView: View {
    @ObservedObject var session: SessionManager

    var body: some View {
        Form {
            Section("Account") {
                LabeledContent("Name", value: session.currentUser?.name ?? "")
                LabeledContent("Email", value: session.currentUser?.email ?? "")
                LabeledContent("Role", value: session.currentUser?.role ?? "")
                LabeledContent("Company", value: session.companyName)
            }

            Section("Admin Stubs") {
                Label("Company profile", systemImage: "building.2")
                Label("Tax rate", systemImage: "percent")
                Label("Product management", systemImage: "shippingbox")
                Label("Contract templates", systemImage: "doc.text")
            }

            Section {
                Button(role: .destructive) {
                    Task { await session.logout() }
                } label: {
                    Text("Logout")
                }
            }
        }
        .navigationTitle("Settings")
    }
}
