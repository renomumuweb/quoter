import Foundation

@MainActor
final class AppState: ObservableObject {
    let localization: AppLocalization
    let apiClient: APIClient
    let tokenStore: TokenStore
    let sessionManager: SessionManager

    init() {
        let localization = AppLocalization()
        let tokenStore = KeychainTokenStore()
        let apiClient = APIClient(baseURL: APIEnvironment.baseURL)
        let sessionManager = SessionManager(apiClient: apiClient, tokenStore: tokenStore)

        self.localization = localization
        self.tokenStore = tokenStore
        self.apiClient = apiClient
        self.sessionManager = sessionManager
    }

    func restoreSession() async {
        await sessionManager.restoreSession()
    }
}
