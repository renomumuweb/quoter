import SwiftUI

struct RegisterView: View {
    @ObservedObject var session: SessionManager
    @StateObject private var viewModel = AuthViewModel()
    @State private var companyName = ""
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: 14) {
            TextField("Company name", text: $companyName)
                .textContentType(.organizationName)
                .textFieldStyle(.roundedBorder)

            TextField("Your name", text: $name)
                .textContentType(.name)
                .textFieldStyle(.roundedBorder)

            TextField("Email", text: $email)
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)

            SecureField("Password", text: $password)
                .textContentType(.newPassword)
                .textFieldStyle(.roundedBorder)

            Button {
                guard viewModel.validate(email: email, password: password, name: name) else { return }
                Task {
                    viewModel.isSubmitting = true
                    await session.register(companyName: companyName, name: name, email: email, password: password)
                    viewModel.isSubmitting = false
                }
            } label: {
                if viewModel.isSubmitting {
                    ProgressView()
                } else {
                    Text("Create Account")
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
