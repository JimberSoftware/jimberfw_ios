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
