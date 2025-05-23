import Foundation
import Alamofire


// Custom logger that filters sensitive information
class CustomLogger: EventMonitor {

    // Log the request details
    func request(_ request: Request, didStartRequest task: URLSessionTask) {
        if let url = request.request?.url {
            print("Starting Request:")
            print("URL: \(url.absoluteString)")
            print("Method: \(request.request?.method?.rawValue ?? "N/A")")

            if let url = request.request?.url, let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems {
                print("Query Parameters: \(queryItems.map { "\($0.name): \($0.value ?? "nil")" }.joined(separator: ", "))")
            }
        }
    }

    // Log the response details (including JSON)
    func request(_ request: Request, didParseResponse response: DataResponse<Data, AFError>) {
        if let message = String(data: response.data ?? Data(), encoding: .utf8) {
            // Log the response body (JSON)
            print("Response JSON: \(message)")

            // Apply filtering for sensitive data (same as your previous example)
            let filteredMessage = message
                .replacingOccurrences(of: "(accessToken\":\")\\S+", with: "$1****\"}", options: .regularExpression)
                .replacingOccurrences(of: "(Authentication=)[^;]+", with: "$1****", options: .regularExpression)
                .replacingOccurrences(of: "(Authorization:)[^;]+", with: "$1****", options: .regularExpression)
                .replacingOccurrences(of: "(Refresh=)[^;]+", with: "$1****", options: .regularExpression)
                .replacingOccurrences(of: "(idToken\":\")\\S+", with: "$1****\"}", options: .regularExpression)

            print("Filtered Response JSON: \(filteredMessage)")
        }
    }

    // Log the error details (in case of failure)
    func request(_ request: Request, didFailWithError error: Error) {
        print("Request failed with error: \(error.localizedDescription)")
    }
}

// AuthInterceptor that handles token renewal
class AuthInterceptor: RequestInterceptor {
    private let excludedUrls: [String] = ["\(ApiClient.BASE_URL)/auth/refresh"]

    func intercept(_ request: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        if excludedUrls.contains(where: { request.url?.absoluteString.starts(with: $0) == true }) {
            completion(.success(request))
            return
        }

        // Intercept request and handle authorization error
        session.request(request)
            .validate(statusCode: 401..<500)
            .responseData { response in
                if response.error != nil {
                    // Handle token renewal and retry logic
                    self.renewJwt { newToken in
                        var newRequest = request
                        newRequest.addValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                        completion(.success(newRequest))
                    }
                } else {
                    completion(.success(request))
                }
            }
    }

    private func renewJwt(completion: @escaping (String?) -> Void) {
        let cookies = getCookieString()

        ApiClient.apiService.refreshToken(cookies: cookies) { result in
            switch result {
            case .success(let response):
                completion(response.accessToken)
            case .failure:
                completion(nil)
            }
        }
    }
}

// API Service for Retrofit-like requests
protocol ApiService {
    func getUserAuthentication(type: String, data: AuthenticationApiRequest, completion: @escaping (Result<UserAuthenticationApiResult, Error>) -> Void)
    func createDaemon(userId: Int, company: String, data: CreateDaemonApiRequest, cookies: String, completion: @escaping (Result<CreateDaemonApiResult, Error>) -> Void)
    func deleteDaemon(daemonId: Int, company: String, authorization: String, completion: @escaping (Result<DeleteDaemonApiResult, Error>) -> Void)
    func sendVerificationEmail(data: VerificationCodeApiRequest, completion: @escaping (Result<Bool, Error>) -> Void)
    func verifyEmailWithToken(data: AuthenticationWithVerificationCodeApiRequest, completion: @escaping (Result<UserAuthenticationApiResult, Error>) -> Void)
    func refreshToken(cookies: String, completion: @escaping (Result<RefreshTokenApiResult, Error>) -> Void)
    func logout(cookies: String, completion: @escaping (Result<Bool, Error>) -> Void)
    func getCloudControllerInformation(daemonId: Int, company: String, authorization: String, completion: @escaping (Result<NetworkControllerApiResult, Error>) -> Void)
}

// ApiClient class
class ApiClient {
    static let BASE_URL = "https://signal.staging.jimber.io/api/v1/"
    static let apiService = ApiServiceImpl()

    private init() {}
}

// API Implementation using Alamofire
class ApiServiceImpl: ApiService {
    private let session: Session

    init() {
        let interceptor = AuthInterceptor()
        let logger = CustomLogger()

        session = Session(interceptor: interceptor, eventMonitors: [logger])
    }

    func getUserAuthentication(type: String, data: AuthenticationApiRequest, completion: @escaping (Result<UserAuthenticationApiResult, Error>) -> Void) {
        let url = "\(ApiClient.BASE_URL)auth/verify-\(type)-id"

        session.request(url, method: .post, parameters: data, encoder: JSONParameterEncoder.default)
               .validate()
               .responseData { response in
                   switch response.result {
                   case .success(let data):
                       do {
                           var result = try JSONDecoder().decode(UserAuthenticationApiResult.self, from: data)
                           if let headers = response.response?.allHeaderFields as? [String: String],
                              let setCookie = headers["Set-Cookie"] {
                               result.authCookie = setCookie
                           }
                           completion(.success(result))
                       } catch {
                           completion(.failure(error))
                       }

                   case .failure(let error):
                       if let data = response.data,
                          let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                          let message = json["message"] as? String {
                           print(message)
                           completion(.failure(NSError(domain: "", code: response.response?.statusCode ?? 0, userInfo: [NSLocalizedDescriptionKey: message])))
                       } else {
                           completion(.failure(error))
                       }
                   }
               }
    }


    func createDaemon(userId: Int,company: String, data: CreateDaemonApiRequest, cookies: String, completion: @escaping (Result<CreateDaemonApiResult, Error>) -> Void) {
        let url = "\(ApiClient.BASE_URL)companies/\(company)/daemons/user/\(userId)"

        session.request(url, method: .post, parameters: data, encoder: JSONParameterEncoder.default, headers: ["Cookie": cookies])
               .validate()
               .responseData { response in
                   switch response.result {
                   case .success(let data):
                       do {
                           let result = try JSONDecoder().decode(CreateDaemonApiResult.self, from: data)
                           completion(.success(result))
                       } catch {
                           completion(.failure(error))
                       }

                   case .failure(let error):
                       if let data = response.data,
                          let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                          let message = json["message"] as? String {
                           print(message)
                           completion(.failure(NSError(domain: "", code: response.response?.statusCode ?? 0, userInfo: [NSLocalizedDescriptionKey: message])))
                       } else {
                           completion(.failure(error))
                       }
                   }
               }
    }


    func deleteDaemon(daemonId: Int, company: String, authorization: String, completion: @escaping (Result<DeleteDaemonApiResult, Error>) -> Void) {
        let url = "\(ApiClient.BASE_URL)companies/\(company)/daemons-mobile/\(daemonId)"

        session.request(url, method: .delete, headers: ["Authorization": authorization])
               .validate()
               .responseData { response in
                   switch response.result {
                   case .success(let data):
                       do {
                           let result = try JSONDecoder().decode(DeleteDaemonApiResult.self, from: data)
                           completion(.success(result))
                       } catch {
                           completion(.failure(error))
                       }

                   case .failure(let error):
                       if let data = response.data,
                          let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                          let message = json["message"] as? String {
                           print(message)
                           completion(.failure(NSError(domain: "", code: response.response?.statusCode ?? 0, userInfo: [NSLocalizedDescriptionKey: message])))
                       } else {
                           completion(.failure(error))
                       }
                   }
               }
    }

    func sendVerificationEmail(data: VerificationCodeApiRequest, completion: @escaping (Result<Bool, Error>) -> Void) {
        let url = "\(ApiClient.BASE_URL)auth/send-user-token-code"

        session.request(url, method: .post, parameters: data, encoder: JSONParameterEncoder.default)
               .validate()
               .responseData { response in
                   switch response.result {
                   case .success(let data):
                       do {
                           let result = try JSONDecoder().decode(Bool.self, from: data)
                           completion(.success(result))
                       } catch {
                           completion(.failure(error))
                       }

                   case .failure(let error):
                       if let data = response.data,
                          let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                          let message = json["message"] as? String {
                           print(message)
                           completion(.failure(NSError(domain: "", code: response.response?.statusCode ?? 0, userInfo: [NSLocalizedDescriptionKey: message])))
                       } else {
                           completion(.failure(error))
                       }
                   }
               }
    }

    func verifyEmailWithToken(data: AuthenticationWithVerificationCodeApiRequest, completion: @escaping (Result<UserAuthenticationApiResult, Error>) -> Void) {
        let url = "\(ApiClient.BASE_URL)auth/verify-email-token"

        session.request(url, method: .post, parameters: data, encoder: JSONParameterEncoder.default)
               .validate()
               .responseData { response in
                   switch response.result {
                   case .success(let data):
                       do {
                           var result = try JSONDecoder().decode(UserAuthenticationApiResult.self, from: data)
                           if let headers = response.response?.allHeaderFields as? [String: String],
                              let setCookie = headers["Set-Cookie"] {
                               result.authCookie = setCookie
                           }
                           completion(.success(result))
                       } catch {
                           completion(.failure(error))
                       }

                   case .failure(let error):
                       if let data = response.data,
                          let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                          let message = json["message"] as? String {
                           print(message)
                           completion(.failure(NSError(domain: "", code: response.response?.statusCode ?? 0, userInfo: [NSLocalizedDescriptionKey: message])))
                       } else {
                           completion(.failure(error))
                       }
                   }
               }
    }


    func refreshToken(cookies: String, completion: @escaping (Result<RefreshTokenApiResult, Error>) -> Void) {
        let url = "\(ApiClient.BASE_URL)auth/refresh"

        session.request(url, method: .get, headers: ["Cookie": cookies])
               .validate()
               .responseData { response in
                   switch response.result {
                   case .success(let data):
                       do {
                           let result = try JSONDecoder().decode(RefreshTokenApiResult.self, from: data)
                           completion(.success(result))
                       } catch {
                           completion(.failure(error))
                       }
                   case .failure(let error):
                       if let data = response.data,
                          let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                          let message = json["message"] as? String {
                           print(message)
                           completion(.failure(NSError(domain: "", code: response.response?.statusCode ?? 0, userInfo: [NSLocalizedDescriptionKey: message])))
                       } else {
                           completion(.failure(error))
                       }
                   }
               }
    }

    func logout(cookies: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        let url = "\(ApiClient.BASE_URL)auth/logout"

        session.request(url, method: .post, headers: ["Cookie": cookies])
               .validate()
               .responseData { response in
                   switch response.result {
                   case .success(let data):
                       do {
                           let result = try JSONDecoder().decode(Bool.self, from: data)
                           completion(.success(result))
                       } catch {
                           completion(.failure(error))
                       }
                   case .failure(let error):
                       if let data = response.data,
                          let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                          let message = json["message"] as? String {
                           print(message)
                           completion(.failure(NSError(domain: "", code: response.response?.statusCode ?? 0, userInfo: [NSLocalizedDescriptionKey: message])))
                       } else {
                           completion(.failure(error))
                       }
                   }
               }
    }

    func getCloudControllerInformation(daemonId: Int, company: String, authorization: String, completion: @escaping (Result<NetworkControllerApiResult, Error>) -> Void) {
        let url = "\(ApiClient.BASE_URL)companies/\(company)/daemons-mobile/\(daemonId)/nc-information"

        session.request(url, method: .get, headers: ["Authorization": authorization])
               .validate()
               .responseData { response in
                   switch response.result {
                   case .success(let data):
                       do {
                           let result = try JSONDecoder().decode(NetworkControllerApiResult.self, from: data)
                           completion(.success(result))
                       } catch {
                           completion(.failure(error))
                       }
                   case .failure(let error):
                       if let data = response.data,
                          let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                          let message = json["message"] as? String {
                           print(message)
                           completion(.failure(NSError(domain: "", code: response.response?.statusCode ?? 0, userInfo: [NSLocalizedDescriptionKey: message])))
                       } else {
                           completion(.failure(error))
                       }
                   }
               }
    }

}
