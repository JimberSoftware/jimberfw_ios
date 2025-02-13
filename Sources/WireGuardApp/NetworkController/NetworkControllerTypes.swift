import Foundation

struct NetworkController: Codable {
    let routerPublicKey: String
    let ipAddress: String
    let endpointAddress: String
    let allowedIps: String
}

struct DnsServer: Codable {
    let ipAddress: String
}
