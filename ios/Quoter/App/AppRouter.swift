import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        RootContent(session: appState.sessionManager)
    }
}

private struct RootContent: View {
    @ObservedObject var session: SessionManager

    var body: some View {
        Group {
            if session.isAuthenticated {
                MainShellView(session: session)
            } else {
                AuthRootView(session: session)
            }
        }
        .overlay {
            if session.isRestoring {
                ZStack {
                    Color.black.opacity(0.08).ignoresSafeArea()
                    ProgressView("Restoring session")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

private enum SidebarItem: String, CaseIterable, Identifiable {
    case projects = "Projects"
    case customers = "Customers"
    case quote = "Quote Preview"
    case contract = "Contract"
    case settings = "Settings"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .projects: return "folder"
        case .customers: return "person.2"
        case .quote: return "list.bullet.rectangle"
        case .contract: return "doc.richtext"
        case .settings: return "gearshape"
        }
    }
}

private struct MainShellView: View {
    @ObservedObject var session: SessionManager
    @State private var selection: SidebarItem? = .projects

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selection) { item in
                Label(item.rawValue, systemImage: item.systemImage)
                    .tag(item)
            }
            .navigationTitle("Quoter")
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.currentUser?.name ?? "Signed in")
                            .font(.footnote.weight(.semibold))
                        Text(session.companyName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } detail: {
            switch selection ?? .projects {
            case .projects:
                ProjectListView()
            case .customers:
                CustomerListView()
            case .quote:
                QuotePreviewView()
            case .contract:
                ContractPreviewView()
            case .settings:
                SettingsView(session: session)
            }
        }
    }
}
