import Foundation

struct TokenPair: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
}

protocol TokenStore {
    func load() throws -> TokenPair?
    func save(_ pair: TokenPair) throws
    func clear() throws
}
