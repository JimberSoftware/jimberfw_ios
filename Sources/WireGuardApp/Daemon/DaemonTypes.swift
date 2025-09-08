import Foundation

struct Daemon: Codable {
    let daemonId: Int
    let name: String
    let ipAddress: String
    let privateKey: String?
}

struct DeletedDaemon: Codable {
    let daemonId: Int
}

struct NetworkIsolationDaemon: Codable {
    let daemonId: Int
    let companyName: String
    let configurationString: String
}

struct DaemonInfo {
    let daemonId: Int
    let name: String
    let isApproved: Bool
}
