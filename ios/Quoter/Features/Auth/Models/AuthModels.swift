import Foundation

struct AppUser: Codable, Identifiable, Equatable {
    let id: UUID
    let companyID: UUID
    let email: String
    let name: String
    let role: String
    let status: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case companyID = "companyId"
        case email
        case name
        case role
        case status
        case createdAt
    }
}

struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresAt: Date
    let user: AppUser
}

struct MeResponse: Codable {
    let user: AppUser
    let companyName: String
}

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

struct RegisterRequest: Encodable {
    let companyName: String
    let name: String
    let email: String
    let password: String
}

struct RefreshRequest: Encodable {
    let refreshToken: String
}

struct LogoutRequest: Encodable {
    let refreshToken: String
}
