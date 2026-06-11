import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

enum APIEnvironment {
    static var baseURL: URL {
        if let value = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
           let url = URL(string: value.hasSuffix("/") ? value : value + "/") {
            return url
        }
        return URL(string: "http://127.0.0.1:8080/api/v1/")!
    }
}

struct APIRequestConfiguration {
    var timeoutInterval: TimeInterval = 18
    var maxRetryCount: Int = 2
}

final class APIClient {
    private let baseURL: URL
    private let session: URLSession
    private let requestConfiguration: APIRequestConfiguration
    var accessTokenProvider: (() async -> String?)?
    var accessTokenRefreshHandler: ((_ forceRefresh: Bool) async throws -> String?)?

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            if let date = APIISO8601DateParser.parse(rawValue) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO8601 date: \(rawValue)"
            )
        }
        return decoder
    }()

    init(
        baseURL: URL,
        session: URLSession? = nil,
        requestConfiguration: APIRequestConfiguration = APIRequestConfiguration()
    ) {
        self.baseURL = baseURL
        self.requestConfiguration = requestConfiguration
        if let providedSession = session {
            self.session = providedSession
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = requestConfiguration.timeoutInterval
            configuration.timeoutIntervalForResource = requestConfiguration.timeoutInterval * Double(requestConfiguration.maxRetryCount + 1)
            self.session = URLSession(configuration: configuration)
        }
    }

    func get<Response: Decodable>(_ path: String, authenticated: Bool = true) async throws -> Response {
        try await send(path: path, method: .get, body: Optional<EmptyRequest>.none, authenticated: authenticated)
    }

    func post<Body: Encodable, Response: Decodable>(
        _ path: String,
        body: Body,
        authenticated: Bool = true
    ) async throws -> Response {
        try await send(path: path, method: .post, body: body, authenticated: authenticated)
    }

    func postNoResponse<Body: Encodable>(_ path: String, body: Body, authenticated: Bool = true) async throws {
        let _: EmptyResponse = try await send(path: path, method: .post, body: body, authenticated: authenticated)
    }

    func put<Body: Encodable, Response: Decodable>(
        _ path: String,
        body: Body,
        authenticated: Bool = true
    ) async throws -> Response {
        try await send(path: path, method: .put, body: body, authenticated: authenticated)
    }

    func putNoResponse<Body: Encodable>(_ path: String, body: Body, authenticated: Bool = true) async throws {
        let _: EmptyResponse = try await send(path: path, method: .put, body: body, authenticated: authenticated)
    }

    func delete(_ path: String, authenticated: Bool = true) async throws {
        let _: EmptyResponse = try await send(path: path, method: .delete, body: Optional<EmptyRequest>.none, authenticated: authenticated)
    }

    private func send<Body: Encodable, Response: Decodable>(
        path: String,
        method: HTTPMethod,
        body: Body?,
        authenticated: Bool
    ) async throws -> Response {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body {
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        request.timeoutInterval = requestConfiguration.timeoutInterval

        if authenticated, let token = try await accessToken(forceRefresh: false) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let maxRetries = retryLimit(for: method)
        let totalAttempts = maxRetries + 1
        var didRefreshAccessToken = false
        for attempt in 1...totalAttempts {
            do {
                return try await execute(
                    request: request,
                    path: path,
                    method: method,
                    attempt: attempt,
                    maxRetries: maxRetries
                )
            } catch let error as URLError {
                let mapped = mapNetworkError(error, attempt: attempt, maxRetries: maxRetries)
                guard shouldRetry(urlError: error, method: method, attempt: attempt, maxRetries: maxRetries) else {
                    throw mapped
                }
                await sleepBeforeRetry(attempt: attempt)
            } catch let error as APIError {
                if authenticated,
                   case .unauthorized = error,
                   !didRefreshAccessToken,
                   let token = try await accessToken(forceRefresh: true) {
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    didRefreshAccessToken = true
                    continue
                }
                guard shouldRetry(apiError: error, method: method, attempt: attempt, maxRetries: maxRetries) else {
                    throw error
                }
                await sleepBeforeRetry(attempt: attempt)
            } catch {
                throw APIError.network(
                    message: error.localizedDescription,
                    attempts: attempt,
                    maxRetries: maxRetries,
                    timeoutSeconds: requestConfiguration.timeoutInterval
                )
            }
        }

        throw APIError.invalidResponse
    }

    private func accessToken(forceRefresh: Bool) async throws -> String? {
        if let refreshHandler = accessTokenRefreshHandler,
           let refreshed = try await refreshHandler(forceRefresh) {
            return refreshed
        }
        return await accessTokenProvider?()
    }

    private func execute<Response: Decodable>(
        request: URLRequest,
        path: String,
        method: HTTPMethod,
        attempt: Int,
        maxRetries: Int
    ) async throws -> Response {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if http.statusCode == 401 {
            throw APIError.unauthorized
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? decoder.decode(APIErrorPayload.self, from: data).error) ?? "Request failed"
            throw APIError.server(
                message: message,
                statusCode: http.statusCode
            )
        }

        if Response.self == EmptyResponse.self {
            return EmptyResponse() as! Response
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decodingFailed("Method: \(method.rawValue), path: \(path). \(error.localizedDescription)")
        }
    }

    private func retryLimit(for method: HTTPMethod) -> Int {
        switch method {
        case .get, .put, .delete:
            return requestConfiguration.maxRetryCount
        case .post:
            return 0
        }
    }

    private func shouldRetry(apiError: APIError, method: HTTPMethod, attempt: Int, maxRetries: Int) -> Bool {
        guard attempt <= maxRetries else { return false }
        guard retryLimit(for: method) > 0 else { return false }
        if case let .server(_, statusCode) = apiError {
            return [408, 429, 500, 502, 503, 504].contains(statusCode)
        }
        return false
    }

    private func shouldRetry(urlError: URLError, method: HTTPMethod, attempt: Int, maxRetries: Int) -> Bool {
        guard attempt <= maxRetries else { return false }
        guard retryLimit(for: method) > 0 else { return false }
        switch urlError.code {
        case .timedOut, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet, .dnsLookupFailed:
            return true
        default:
            return false
        }
    }

    private func mapNetworkError(_ error: URLError, attempt: Int, maxRetries: Int) -> APIError {
        if error.code == .timedOut {
            return .timeout(seconds: requestConfiguration.timeoutInterval, attempts: attempt, maxRetries: maxRetries)
        }
        return .network(
            message: error.localizedDescription,
            attempts: attempt,
            maxRetries: maxRetries,
            timeoutSeconds: requestConfiguration.timeoutInterval
        )
    }

    private func sleepBeforeRetry(attempt: Int) async {
        let delay = UInt64(350_000_000 * attempt)
        try? await Task.sleep(nanoseconds: delay)
    }
}

struct EmptyRequest: Encodable {}
struct EmptyResponse: Decodable {}

private struct APIErrorPayload: Decodable {
    let error: String
}

private enum APIISO8601DateParser {
    private static let withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let withoutFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func parse(_ rawValue: String) -> Date? {
        if let date = withFractionalSeconds.date(from: rawValue) {
            return date
        }
        if let date = withoutFractionalSeconds.date(from: rawValue) {
            return date
        }
        if let normalized = normalizeFractionalSeconds(rawValue),
           let date = withFractionalSeconds.date(from: normalized) {
            return date
        }
        return nil
    }

    private static func normalizeFractionalSeconds(_ value: String) -> String? {
        guard let dot = value.firstIndex(of: ".") else { return nil }
        let fractionStart = value.index(after: dot)
        let suffix = value[fractionStart...]
        guard let timezoneIndexInSuffix = suffix.firstIndex(where: { $0 == "Z" || $0 == "+" || $0 == "-" }) else {
            return nil
        }

        let fraction = suffix[..<timezoneIndexInSuffix]
        guard !fraction.isEmpty else { return nil }

        let padded = String(fraction.prefix(3)).padding(toLength: 3, withPad: "0", startingAt: 0)
        return String(value[..<fractionStart]) + padded + String(suffix[timezoneIndexInSuffix...])
    }
}
