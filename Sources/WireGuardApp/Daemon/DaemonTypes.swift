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

enum DaemonInfoError: LocalizedError {
    case signingError

    var errorDescription: String? {
        switch self {
        case .signingError:
            return "Could not authenticate with the server. Please sign in again."
        }
    }
}

enum DaemonRegistrationError: LocalizedError {
    case invalidKeys
    case invalidNetworkConfiguration

    var errorDescription: String? {
        switch self {
        case .invalidKeys:
            return "Could not create the tunnel keys. Please try again."
        case .invalidNetworkConfiguration:
            return "The server returned an invalid network configuration. Please contact support."
        }
    }
}
