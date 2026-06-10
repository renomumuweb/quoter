import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var localization: AppLocalization
    @ObservedObject var session: SessionManager

    var body: some View {
        Form {
            Section("Language") {
                Picker("Language", selection: languageBinding) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName)
                            .tag(language)
                            .disabled(!language.isSelectable)
                    }
                }

                Text("French and Italian are reserved for future expansion.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("How to use Quoter") {
                NavigationLink {
                    TutorialGuideView()
                } label: {
                    Label("Inspect, bind, quote, and send", systemImage: "questionmark.circle")
                }
            }

            Section("Account") {
                LabeledContent("Name", value: session.currentUser?.name ?? "")
                LabeledContent("Email", value: session.currentUser?.email ?? "")
                LabeledContent("Role", value: AppLanguage.localizedKnownSystemString(session.currentUser?.role ?? "", language: localization.language))
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

    private var languageBinding: Binding<AppLanguage> {
        Binding {
            localization.language
        } set: { language in
            localization.setLanguage(language)
        }
    }
}
