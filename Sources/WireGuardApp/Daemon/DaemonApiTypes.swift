import Foundation

struct CreateDaemonApiResult: Codable {
    let id: Int
    let ipAddress: String
    let name: String
}

struct DeleteDaemonApiResult: Codable {
    let id: Int
}

struct CreateDaemonApiRequest: Codable {
    let publicKey: String
    let name: String
}

struct GetDaemonInformationApiResult: Codable {
    let id: Int
    let name: String
    let approvalStatus: String
}

