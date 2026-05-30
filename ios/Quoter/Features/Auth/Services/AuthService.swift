import Foundation

struct AuthService {
    let apiClient: APIClient

    func register(companyName: String, name: String, email: String, password: String) async throws -> AuthResponse {
        try await apiClient.post(
            "auth/register",
            body: RegisterRequest(companyName: companyName, name: name, email: email, password: password),
            authenticated: false
        )
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        try await apiClient.post(
            "auth/login",
            body: LoginRequest(email: email, password: password),
            authenticated: false
        )
    }

    func refresh(refreshToken: String) async throws -> AuthResponse {
        try await apiClient.post(
            "auth/refresh",
            body: RefreshRequest(refreshToken: refreshToken),
            authenticated: false
        )
    }

    func me() async throws -> MeResponse {
        try await apiClient.get("auth/me", authenticated: true)
    }

    func logout(refreshToken: String) async throws {
        try await apiClient.postNoResponse(
            "auth/logout",
            body: LogoutRequest(refreshToken: refreshToken),
            authenticated: true
        )
    }
}
