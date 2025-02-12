import Foundation

struct VerificationCodeApiRequest: Codable {
    let email: String
}

struct AuthenticationWithVerificationCodeApiRequest: Codable {
    let email: String
    let token: Int
}
