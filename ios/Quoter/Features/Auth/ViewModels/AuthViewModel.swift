import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isSubmitting = false
    @Published var validationMessage: String?

    func validate(email: String, password: String, name: String? = nil) -> Bool {
        validationMessage = nil
        if let name, name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            validationMessage = "Name is required."
            return false
        }
        if !email.contains("@") {
            validationMessage = "Enter a valid email."
            return false
        }
        if password.count < 10 {
            validationMessage = "Password must be at least 10 characters."
            return false
        }
        return true
    }
}
