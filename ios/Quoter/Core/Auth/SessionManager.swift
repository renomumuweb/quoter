import Foundation

@MainActor
final class SessionManager: ObservableObject {
    @Published private(set) var currentUser: AppUser?
    @Published private(set) var companyName: String = ""
    @Published private(set) var isRestoring = true
    @Published var errorMessage: String?

    private let authService: AuthService
    private let tokenStore: TokenStore
    private var tokenPair: TokenPair?
    private var refreshTask: Task<AuthResponse, Error>?
    private let refreshLeeway: TimeInterval = 60

    var isAuthenticated: Bool {
        currentUser != nil && tokenPair != nil
    }

    init(apiClient: APIClient, tokenStore: TokenStore) {
        self.authService = AuthService(apiClient: apiClient)
        self.tokenStore = tokenStore
        apiClient.accessTokenProvider = { [weak self] in
            await MainActor.run { self?.tokenPair?.accessToken }
        }
        apiClient.accessTokenRefreshHandler = { [weak self] forceRefresh in
            guard let self else { return nil }
            return try await self.validAccessToken(forceRefresh: forceRefresh)
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
            } catch APIError.unauthorized {
                try await refreshSession()
                try await loadMe()
            } catch {
                errorMessage = AppLanguage.localizedString("Saved session found, but the server could not be reached.")
            }
        } catch {
            if isAuthenticationFailure(error) {
                clearLocalSession()
            } else {
                errorMessage = AppLanguage.localizedErrorDescription(error)
            }
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
        _ = try? await validAccessToken(forceRefresh: false)
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
            errorMessage = AppLanguage.localizedErrorDescription(error)
        }
    }

    private func refreshSession() async throws {
        if let refreshTask {
            let response = try await refreshTask.value
            try save(response: response, updateUser: currentUser == nil)
            return
        }

        guard let refreshToken = tokenPair?.refreshToken else { throw APIError.unauthorized }
        let task = Task { [authService] in
            try await authService.refresh(refreshToken: refreshToken)
        }
        refreshTask = task
        defer { refreshTask = nil }

        let response = try await task.value
        try save(response: response, updateUser: currentUser == nil)
    }

    private func loadMe() async throws {
        let response = try await authService.me()
        currentUser = response.user
        companyName = response.companyName
    }

    private func save(response: AuthResponse, updateUser: Bool = true) throws {
        let pair = TokenPair(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            expiresAt: response.expiresAt
        )
        try tokenStore.save(pair)
        tokenPair = pair
        if updateUser {
            currentUser = response.user
            if companyName.isEmpty {
                companyName = response.user.companyID.uuidString
            }
        }
    }

    private func clearLocalSession() {
        refreshTask?.cancel()
        refreshTask = nil
        try? tokenStore.clear()
        tokenPair = nil
        currentUser = nil
        companyName = ""
    }

    private func validAccessToken(forceRefresh: Bool) async throws -> String? {
        guard let pair = tokenPair else { return nil }

        if !forceRefresh, pair.expiresAt > Date().addingTimeInterval(refreshLeeway) {
            return pair.accessToken
        }

        do {
            try await refreshSession()
            return tokenPair?.accessToken
        } catch {
            if isAuthenticationFailure(error) {
                clearLocalSession()
            }
            throw error
        }
    }

    private func isAuthenticationFailure(_ error: Error) -> Bool {
        if case APIError.unauthorized = error {
            return true
        }
        if case let APIError.server(_, statusCode) = error, statusCode == 401 || statusCode == 403 {
            return true
        }
        return false
    }
}
