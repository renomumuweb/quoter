import Foundation

@MainActor
final class SessionManager: ObservableObject {
    @Published private(set) var currentUser: AppUser?
    @Published private(set) var companyName: String = ""
    @Published private(set) var isRestoring = false
    @Published var errorMessage: String?

    private let authService: AuthService
    private let tokenStore: TokenStore
    private var tokenPair: TokenPair?

    var isAuthenticated: Bool {
        currentUser != nil && tokenPair != nil
    }

    init(apiClient: APIClient, tokenStore: TokenStore) {
        self.authService = AuthService(apiClient: apiClient)
        self.tokenStore = tokenStore
        apiClient.accessTokenProvider = { [weak self] in
            await MainActor.run { self?.tokenPair?.accessToken }
        }
    }

    func restoreSession() async {
        isRestoring = true
        defer { isRestoring = false }

        do {
            guard let saved = try tokenStore.load() else { return }
            tokenPair = saved
            do {
                try await loadMe()
            } catch {
                try await refreshSession()
                try await loadMe()
            }
        } catch {
            clearLocalSession()
        }
    }

    func login(email: String, password: String) async {
        await performAuth {
            try await authService.login(email: email, password: password)
        }
    }

    func register(companyName: String, name: String, email: String, password: String) async {
        await performAuth {
            try await authService.register(companyName: companyName, name: name, email: email, password: password)
        }
    }

    func logout() async {
        if let refreshToken = tokenPair?.refreshToken {
            try? await authService.logout(refreshToken: refreshToken)
        }
        clearLocalSession()
    }

    private func performAuth(_ operation: () async throws -> AuthResponse) async {
        errorMessage = nil
        do {
            let response = try await operation()
            try save(response: response)
            try? await loadMe()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshSession() async throws {
        guard let refreshToken = tokenPair?.refreshToken else { throw APIError.unauthorized }
        let response = try await authService.refresh(refreshToken: refreshToken)
        try save(response: response)
    }

    private func loadMe() async throws {
        let response = try await authService.me()
        currentUser = response.user
        companyName = response.companyName
    }

    private func save(response: AuthResponse) throws {
        let pair = TokenPair(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            expiresAt: response.expiresAt
        )
        try tokenStore.save(pair)
        tokenPair = pair
        currentUser = response.user
        companyName = response.user.companyID.uuidString
    }

    private func clearLocalSession() {
        try? tokenStore.clear()
        tokenPair = nil
        currentUser = nil
        companyName = ""
    }
}
