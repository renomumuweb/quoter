import Foundation

enum APIError: LocalizedError, Equatable {
    case invalidURL
    case invalidResponse
    case unauthorized
    case server(message: String, statusCode: Int)
    case timeout(seconds: TimeInterval, attempts: Int, maxRetries: Int)
    case network(message: String, attempts: Int, maxRetries: Int, timeoutSeconds: TimeInterval)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return AppLanguage.localizedString("The API URL is invalid. Please check the server address.")
        case .invalidResponse:
            return AppLanguage.localizedString("The server returned an invalid response. Please retry after checking the API status.")
        case .unauthorized:
            return AppLanguage.localizedString("Your session has expired. Please sign in again.")
        case let .server(message, _):
            return AppLanguage.localizedServerMessage(message)
        case let .timeout(seconds, attempts, maxRetries):
            return AppLanguage.localizedFormat(
                "Request timed out after %@s. Attempts: %@/%@, retries: %@.",
                Self.format(seconds),
                "\(attempts)",
                "\(maxRetries + 1)",
                "\(maxRetries)"
            )
        case let .network(_, attempts, maxRetries, timeoutSeconds):
            return AppLanguage.localizedFormat(
                "Network request failed. Timeout: %@s, attempts: %@/%@, retries: %@.",
                Self.format(timeoutSeconds),
                "\(attempts)",
                "\(maxRetries + 1)",
                "\(maxRetries)"
            )
        case .decodingFailed:
            return AppLanguage.localizedString("The server response could not be read. Please retry.")
        }
    }

    private static func format(_ value: TimeInterval) -> String {
        String(format: "%.0f", value)
    }
}
