import Foundation

struct NetworkController: Codable {
    let routerPublicKey: String
    let ipAddress: String
    let endpointAddress: String
    let allowedIps: String
}
