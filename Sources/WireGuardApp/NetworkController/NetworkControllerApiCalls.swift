import Foundation

func getDaemonConnectionData(daemonId: Int, companyName: String, sk: String) async throws -> NetworkController {
    let timestampInSeconds = Int(Date().timeIntervalSince1970)
    let timestampBuffer = withUnsafeBytes(of: UInt64(timestampInSeconds).littleEndian) { Data($0) }

    let authorizationHeader = generateSignedMessage(message: timestampBuffer, privateKey: sk)

    return try await withCheckedThrowingContinuation { continuation in
        ApiClient.apiService.getCloudControllerInformation(daemonId: daemonId, company: companyName, authorization: authorizationHeader!) { result in
            switch result {
            case .success(let response):
                let networkController = NetworkController(
                     routerPublicKey: response.routerPublicKey,
                    ipAddress: response.ipAddress,
                    endpointAddress: response.endpointAddress,
                    allowedIps: response.allowedIps
                )
                continuation.resume(returning: networkController)

            case .failure(let error):
                continuation.resume(throwing: error)
            }
        }
    }
}
