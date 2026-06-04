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
            return "The API URL is invalid. Please check the server address."
        case .invalidResponse:
            return "The server returned an invalid response. Please retry after checking the API status."
        case .unauthorized:
            return "Your session has expired. Please sign in again."
        case let .server(message, _):
            return message
        case let .timeout(seconds, attempts, maxRetries):
            return "Request timed out after \(Self.format(seconds))s. Attempts: \(attempts)/\(maxRetries + 1), retries: \(maxRetries)."
        case let .network(message, attempts, maxRetries, timeoutSeconds):
            return "Network request failed: \(message). Timeout: \(Self.format(timeoutSeconds))s, attempts: \(attempts)/\(maxRetries + 1), retries: \(maxRetries)."
        case let .decodingFailed(message):
            return "The server response could not be read. \(message)"
        }
    }

    private static func format(_ value: TimeInterval) -> String {
        String(format: "%.0f", value)
    }
}
