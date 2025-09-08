import Foundation

func createDaemon(userId: Int, company: String, daemonData: CreateDaemonApiRequest) async throws -> Daemon {
    let cookies = getCookieString()

    return try await withCheckedThrowingContinuation { continuation in
        ApiClient.apiService.createDaemon(userId: userId, company: company, data: daemonData, cookies: cookies) { result in
            switch result {
            case .success(let response):
                let daemon = Daemon(
                    daemonId: response.id,
                    name: response.name,
                    ipAddress: response.ipAddress,
                    privateKey: nil
                )
                continuation.resume(returning: daemon)

            case .failure(let error):
                continuation.resume(throwing: error)
            }
        }
    }
}

func deleteDaemon(daemonId: Int, company: String, sk: String) async -> Result<DeletedDaemon, Error> {
    let timestampInSeconds = Int(Date().timeIntervalSince1970)
    let timestampBuffer = withUnsafeBytes(of: UInt64(timestampInSeconds).littleEndian) { Data($0) }

    guard let authorizationHeader = generateSignedMessage(message: timestampBuffer, privateKey: sk) else {
        return .failure(NSError(domain: "AuthorizationError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to generate authorization header"]))
    }

    return await withCheckedContinuation { continuation in
        ApiClient.apiService.deleteDaemon(daemonId: daemonId, company: company, authorization: authorizationHeader) { result in
            switch result {
            case .success(let response):
                let deletedDaemon = DeletedDaemon(daemonId: response.id)
                continuation.resume(returning: .success(deletedDaemon))

            case .failure(let error):
                continuation.resume(returning: .failure(error))
            }
        }
    }
}

func getDaemonApprovalStatus(daemonId: Int, company: String, sk: String) async -> Bool? {
    let timestampInSeconds = Int(Date().timeIntervalSince1970)
    let timestampBuffer = withUnsafeBytes(of: UInt64(timestampInSeconds).littleEndian) { Data($0) }

    guard let authorizationHeader = generateSignedMessage(message: timestampBuffer, privateKey: sk) else {
        return nil
    }

    print(authorizationHeader)

    return await withCheckedContinuation { continuation in
        ApiClient.apiService.getDaemonInformation(daemonId: daemonId, company: company, authorization: authorizationHeader) { result in
            switch result {
            case .success(let response):
                let isApproved = (response.approvalStatus == "approved")
                continuation.resume(returning: isApproved)

            case .failure(let error):
                print(error)
                continuation.resume(returning: nil)
            }
        }
    }
}





