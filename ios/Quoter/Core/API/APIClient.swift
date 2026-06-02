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

final class APIClient {
    private let baseURL: URL
    private let session: URLSession
    var accessTokenProvider: (() async -> String?)?

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

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
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

        if authenticated, let token = await accessTokenProvider?() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if http.statusCode == 401 {
            throw APIError.unauthorized
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? decoder.decode(APIErrorPayload.self, from: data).error) ?? "Request failed"
            throw APIError.server(message: message, statusCode: http.statusCode)
        }

        if Response.self == EmptyResponse.self {
            return EmptyResponse() as! Response
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decodingFailed(error.localizedDescription)
        }
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
