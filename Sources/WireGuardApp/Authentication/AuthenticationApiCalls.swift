import Foundation
import Combine

func getUserAuthentication(idToken: String, authenticationType: AuthenticationType) async -> UserAuthentication? {
    let type: String
    switch authenticationType {
    case .google:
        type = "google"
    case .microsoft:
        type = "microsoft"
    }

    let authRequest = AuthenticationApiRequest(idToken: idToken)

    // Use async/await to handle the completion handler
    return await withCheckedContinuation { continuation in
        ApiClient.apiService.getUserAuthentication(type: type, data: authRequest) { result in
            switch result {
            case .success(let userAuthResult):
                // Handle success, map to the UserAuthentication model
                let userAuthentication = UserAuthentication(
                    userId: userAuthResult.id,
                    companyName: userAuthResult.company.name
                )
                // Return the result
                continuation.resume(returning: userAuthentication)

            case .failure(let error):
                // Handle failure
                continuation.resume(returning: nil)
            }
        }
    }
}


private var subscriptions = Set<AnyCancellable>()
