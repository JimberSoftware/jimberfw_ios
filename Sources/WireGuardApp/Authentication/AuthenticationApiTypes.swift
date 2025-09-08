import Foundation

struct UserAuthenticationApiResult: Codable {
    let id: Int
    let email: String
    let company: Company
    var authCookie: String?
}

struct RefreshTokenApiResult: Codable {
    let accessToken: String
}

struct AuthenticationApiRequest: Codable {
    let idToken: String
}
