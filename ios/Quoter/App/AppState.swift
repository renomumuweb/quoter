import Foundation

@MainActor
final class AppState: ObservableObject {
    let apiClient: APIClient
    let tokenStore: TokenStore
    let sessionManager: SessionManager

    init() {
        let tokenStore = KeychainTokenStore()
        let apiClient = APIClient(baseURL: APIEnvironment.baseURL)
        let sessionManager = SessionManager(apiClient: apiClient, tokenStore: tokenStore)

        self.tokenStore = tokenStore
        self.apiClient = apiClient
        self.sessionManager = sessionManager
    }

    func restoreSession() async {
        await sessionManager.restoreSession()
    }
}
