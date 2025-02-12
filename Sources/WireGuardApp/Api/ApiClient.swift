// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Foundation
import Alamofire
import Combine

// MARK: - AuthEventManager
class AuthEventManager {
    static let shared = AuthEventManager()
    let authFailedEvent = PassthroughSubject<Bool, Never>()
}

// MARK: - AuthInterceptor
final class AuthInterceptor: RequestInterceptor, @unchecked Sendable {
    private let excludedUrls: [String] = [
        "https://signal.staging.jimber.io/api/v1/auth/refresh"
    ]

    func adapt(_ urlRequest: URLRequest, for session: Alamofire.Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        // Modify request before it's sent
        completion(.success(urlRequest))
    }

    func retry(_ request: Request, for session: Alamofire.Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
        guard let response = request.response, response.statusCode == 401 else {
            completion(.doNotRetry)
            return
        }

        Task {
            if let newToken = await renewJwt() {
                var newRequest = request.request
                newRequest?.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                completion(.retry)
            } else {
                completion(.doNotRetry)
            }
        }
    }

    private func renewJwt() async -> String? {
        do {
            let newAccessToken = try await withCheckedThrowingContinuation { continuation in
                ApiClient.shared.refreshToken()
                    .sink(
                        receiveCompletion: { completion in
                            switch completion {
                            case .failure(let error):
                                continuation.resume(throwing: error)
                            case .finished:
                                break
                            }
                        },
                        receiveValue: { result in
                            continuation.resume(returning: result.accessToken)
                        }
                    )
                    .store(in: &subscriptions)
            }
            return newAccessToken
            } catch {
                print("Error renewing JWT: \(error)")
                return nil
            }
    }

    private var subscriptions = Set<AnyCancellable>()
}

// MARK: - TokenManager
class TokenManager {
    static let shared = TokenManager()
    var accessToken: String?

    func renewJwt(completion: @escaping (String?) -> Void) {
        ApiClient.shared.refreshToken().sink(receiveCompletion: { _ in }, receiveValue: { result in
            if result.accessToken != "" {
                self.accessToken = result.accessToken
                completion(result.accessToken)
            } else {
                completion(nil)
            }
        }).store(in: &subscriptions)
    }

    private var subscriptions = Set<AnyCancellable>()
}

// MARK: - ApiClient
class ApiClient {
    static let shared = ApiClient()
    private let baseURL = "https://signal.staging.jimber.io/api/v1/"
    private let session: Session

    private init() {
        let interceptor = AuthInterceptor()
        self.session = Session(interceptor: interceptor)
    }

    func request<T: Decodable>(_ endpoint: String, method: HTTPMethod, parameters: Parameters? = nil, headers: HTTPHeaders? = nil) -> AnyPublisher<T, AFError> {
        let url = baseURL + endpoint
        return session.request(url, method: method, parameters: parameters, encoding: JSONEncoding.default, headers: headers)
            .validate()
            .publishDecodable(type: T.self)
            .value()
            .eraseToAnyPublisher()
    }

    func refreshToken() -> AnyPublisher<RefreshTokenApiResult, AFError> {
        request("auth/refresh", method: .get)
    }

    func getUserAuthentication(type: String, data: AuthenticationApiRequest) -> AnyPublisher<UserAuthenticationApiResult, AFError> {
        request("auth/verify-\(type)-id", method: .post, parameters: data.toDictionary())
    }

    func createDaemon(userId: Int, company: String, data: CreateDaemonApiRequest) -> AnyPublisher<CreateDaemonApiResult, AFError> {
        request("companies/\(company)/daemons/user/\(userId)", method: .post, parameters: data.toDictionary())
    }

    func deleteDaemon(company: String, daemonId: Int) -> AnyPublisher<DeleteDaemonApiResult, AFError> {
        request("companies/\(company)/daemons-mobile/\(daemonId)", method: .delete)
    }

    func sendVerificationEmail(data: VerificationCodeApiRequest) -> AnyPublisher<Bool, AFError> {
        request("auth/send-user-token-code", method: .post, parameters: data.toDictionary())
    }

    func verifyEmailWithToken(data: AuthenticationWithVerificationCodeApiRequest) -> AnyPublisher<UserAuthenticationApiResult, AFError> {
        request("auth/verify-email-token", method: .post, parameters: data.toDictionary())
    }

    func logout() -> AnyPublisher<Bool, AFError> {
        request("auth/logout", method: .post)
    }

    func getCloudControllerInformation(company: String, daemonId: Int) -> AnyPublisher<NetworkControllerApiResult, AFError> {
        request("companies/\(company)/daemons-mobile/\(daemonId)/nc-information", method: .get)
    }
}

// MARK: - Helper Extensions
extension Encodable {
    func toDictionary() -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any]
    }
}

