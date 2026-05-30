import SwiftUI

struct LoginView: View {
    @ObservedObject var session: SessionManager
    @StateObject private var viewModel = AuthViewModel()
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: 14) {
            TextField("Email", text: $email)
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)

            SecureField("Password", text: $password)
                .textContentType(.password)
                .textFieldStyle(.roundedBorder)

            Button {
                guard viewModel.validate(email: email, password: password) else { return }
                Task {
                    viewModel.isSubmitting = true
                    await session.login(email: email, password: password)
                    viewModel.isSubmitting = false
                }
            } label: {
                if viewModel.isSubmitting {
                    ProgressView()
                } else {
                    Text("Login")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isSubmitting)

            messageView
        }
        .frame(maxWidth: 420)
    }

    @ViewBuilder
    private var messageView: some View {
        if let message = viewModel.validationMessage ?? session.errorMessage {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
