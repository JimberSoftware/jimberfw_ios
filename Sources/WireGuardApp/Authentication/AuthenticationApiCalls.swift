import Foundation
import Combine

func getUserAuthentication(idToken: String, authenticationType: AuthenticationType) async throws -> UserAuthentication {
    let type: String
    switch authenticationType {
    case .google:
        type = "google"
    case .microsoft:
        type = "microsoft"
    }

    let authRequest = AuthenticationApiRequest(idToken: idToken)

    return try await withCheckedThrowingContinuation { continuation in
        ApiClient.apiService.getUserAuthentication(type: type, data: authRequest) { result in
            switch result {
            case .success(let userAuthResult):
                let userAuthentication = UserAuthentication(
                    userId: userAuthResult.id,
                    companyName: userAuthResult.company.name
                )

                let user = User(id: userAuthResult.id, email: userAuthResult.email)

                saveDataToLocalStorage(cookies: userAuthResult.authCookie!, user: user)
                continuation.resume(returning: userAuthentication)

            case .failure(let error):
                continuation.resume(throwing: error)
            }
        }
    }
}

private var subscriptions = Set<AnyCancellable>()
