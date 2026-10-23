import Foundation

enum AuthenticationType: String, Codable {
    case google = "Google"
    case microsoft = "Microsoft"
}

struct AuthenticationToken: Codable {
    let accessToken: String
}

struct UserAuthentication: Codable {
    let userId: Int
    let companyName: String
}

struct Company: Codable {
    let name: String
}

struct User: Codable {
    let id: Int
    let email: String
}

enum AuthenticationError: LocalizedError {
    case missingSessionCookie

    var errorDescription: String? {
        switch self {
        case .missingSessionCookie:
            return "Sign-in failed: the server did not return a session. Please try again."
        }
    }
}
