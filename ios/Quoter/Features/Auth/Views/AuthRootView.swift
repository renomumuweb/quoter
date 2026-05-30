import SwiftUI

struct AuthRootView: View {
    @ObservedObject var session: SessionManager
    @State private var mode: AuthMode = .login

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text("Quoter")
                        .font(.largeTitle.weight(.bold))
                    Text("iPad field sketching, product binding, quotes, and contracts.")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                Picker("Mode", selection: $mode) {
                    ForEach(AuthMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 420)

                if mode == .login {
                    LoginView(session: session)
                } else {
                    RegisterView(session: session)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .background(Color(.systemGroupedBackground))
        }
    }
}

private enum AuthMode: CaseIterable, Identifiable {
    case login
    case register

    var id: Self { self }

    var title: String {
        switch self {
        case .login: return "Login"
        case .register: return "Register"
        }
    }
}
