import Foundation
import Combine

func getUserAuthentication(idToken: String, authenticationType: AuthenticationType) async -> Result<UserAuthentication, Error> {
    let type: String
    switch authenticationType {
    case .google:
        type = "google"
    case .microsoft:
        type = "microsoft"
    }

    let authRequest = AuthenticationApiRequest(idToken: idToken)
    // Create a Future to bridge Combine to async/await
    let future = Future<UserAuthentication, Error> { promise in
        ApiClient.shared.getUserAuthentication(type: type, data: authRequest)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    promise(.failure(error))
                case .finished:
                    break
                }
            }, receiveValue: { apiResult in
                // Assuming the response contains the userId and companyName
                let userAuthentication = UserAuthentication(
                    userId: apiResult.id,
                    companyName: apiResult.company.name
                )
                promise(.success(userAuthentication))
            })
            .store(in: &subscriptions)
    }

    do {
          // Await the future and return the result
          let userAuthentication = try await future.value
          return .success(userAuthentication)
      } catch {
          // Handle errors that occur during the network call
          return .failure(error)
      }
}

private var subscriptions = Set<AnyCancellable>()
