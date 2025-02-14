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
    private let excludedUrls: [String] = ["https://staging.jimber.io/api/v1/auth/refresh"]

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
        // Call to refresh token
        ApiClient.apiService.refreshToken(cookies: "cookie_string_here") { result in
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
    func getUserAuthentication(type: String, data: AuthenticationApiRequest, completion: @escaping (Result<UserAuthenticationApiResult, AFError>) -> Void)
    func createDaemon(userId: Int, company: String, data: CreateDaemonApiRequest, cookies: String, completion: @escaping (Result<CreateDaemonApiResult, AFError>) -> Void)
    func deleteDaemon(daemonId: Int, company: String, authorization: String, completion: @escaping (Result<DeleteDaemonApiResult, AFError>) -> Void)
    func sendVerificationEmail(data: VerificationCodeApiRequest, completion: @escaping (Result<Bool, AFError>) -> Void)
    func verifyEmailWithToken(data: AuthenticationWithVerificationCodeApiRequest, completion: @escaping (Result<UserAuthenticationApiResult, AFError>) -> Void)
    func refreshToken(cookies: String, completion: @escaping (Result<RefreshTokenApiResult, AFError>) -> Void)
    func logout(cookies: String, completion: @escaping (Result<Bool, AFError>) -> Void)
    func getCloudControllerInformation(daemonId: Int, company: String, authorization: String, completion: @escaping (Result<NetworkControllerApiResult, AFError>) -> Void)
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

    func getUserAuthentication(type: String, data: AuthenticationApiRequest, completion: @escaping (Result<UserAuthenticationApiResult, AFError>) -> Void) {
        session.request("\(ApiClient.BASE_URL)auth/verify-\(type)-id", method: .post, parameters: data, encoder: JSONParameterEncoder.default)
            .responseDecodable(of: UserAuthenticationApiResult.self) { response in
                switch response.result {
                case .success(var apiResult):
                    if let headers = response.response?.allHeaderFields as? [String: String],
                       let setCookie = headers["Set-Cookie"] {
                        apiResult.authCookie = setCookie
                    }
                    completion(.success(apiResult))

                case .failure(let error):
                    completion(.failure(error))
                }
            }
    }


    func createDaemon(userId: Int, company: String, data: CreateDaemonApiRequest, cookies: String, completion: @escaping (Result<CreateDaemonApiResult, AFError>) -> Void) {
        session.request("\(ApiClient.BASE_URL)companies/\(company)/daemons/user/\(userId)", method: .post, parameters: data, encoder: JSONParameterEncoder.default, headers: ["Cookie": cookies])
            .responseDecodable(of: CreateDaemonApiResult.self) { response in
                completion(response.result)
            }
    }

    func deleteDaemon(daemonId: Int, company: String, authorization: String, completion: @escaping (Result<DeleteDaemonApiResult, AFError>) -> Void) {
        session.request("\(ApiClient.BASE_URL)companies/\(company)/daemons-mobile/\(daemonId)", method: .delete, headers: ["Authorization": authorization])
            .responseDecodable(of: DeleteDaemonApiResult.self) { response in
                completion(response.result)
            }
    }

    func sendVerificationEmail(data: VerificationCodeApiRequest, completion: @escaping (Result<Bool, AFError>) -> Void) {
        session.request("\(ApiClient.BASE_URL)auth/send-user-token-code", method: .post, parameters: data, encoder: JSONParameterEncoder.default)
            .responseDecodable(of: Bool.self) { response in
                completion(response.result)
            }
    }

    func verifyEmailWithToken(data: AuthenticationWithVerificationCodeApiRequest, completion: @escaping (Result<UserAuthenticationApiResult, AFError>) -> Void) {
        session.request("\(ApiClient.BASE_URL)auth/verify-email-token", method: .post, parameters: data, encoder: JSONParameterEncoder.default)
            .responseDecodable(of: UserAuthenticationApiResult.self) { response in
                completion(response.result)
            }
    }

    func refreshToken(cookies: String, completion: @escaping (Result<RefreshTokenApiResult, AFError>) -> Void) {
        session.request("\(ApiClient.BASE_URL)auth/refresh", method: .get, headers: ["Cookie": cookies])
            .responseDecodable(of: RefreshTokenApiResult.self) { response in
                completion(response.result)
            }
    }

    func logout(cookies: String, completion: @escaping (Result<Bool, AFError>) -> Void) {
        session.request("\(ApiClient.BASE_URL)auth/logout", method: .post, headers: ["Cookie": cookies])
            .responseDecodable(of: Bool.self) { response in
                completion(response.result)
            }
    }

    func getCloudControllerInformation(daemonId: Int, company: String, authorization: String, completion: @escaping (Result<NetworkControllerApiResult, AFError>) -> Void) {
        session.request("\(ApiClient.BASE_URL)companies/\(company)/daemons-mobile/\(daemonId)/nc-information", method: .get, headers: ["Authorization": authorization])
            .responseDecodable(of: NetworkControllerApiResult.self) { response in
                completion(response.result)
            }
    }
}
