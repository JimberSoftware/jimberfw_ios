import Foundation
import Alamofire

// MARK: - Custom Logger
class CustomLogger: EventMonitor {
    let queue = DispatchQueue(label: "com.wireguard.ios")

    func requestDidResume(_ request: Request) {
        guard let url = request.request?.url else { return }
        wg_log(.info, message: "Request Started: \(request.request?.httpMethod ?? "N/A") \(url.absoluteString)")
        if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems {
            let params = queryItems.map { "\($0.name): \($0.value ?? "nil")" }.joined(separator: ", ")
            if !params.isEmpty {
                wg_log(.info, message: "Query Parameters: \(params)")
            }
        }
    }

    func request(_ request: DataRequest, didParseResponse response: DataResponse<Data?, AFError>) {
        if let data = response.data, !data.isEmpty, let jsonString = String(data: data, encoding: .utf8) {
            let filteredMessage = jsonString
                .replacingOccurrences(of: "(accessToken\":\")\\S+", with: "$1****\"", options: .regularExpression)
                .replacingOccurrences(of: "(Authentication=)[^;]+", with: "$1****", options: .regularExpression)
                .replacingOccurrences(of: "(Authorization:)[^;]+", with: "$1****", options: .regularExpression)
                .replacingOccurrences(of: "(Refresh=)[^;]+", with: "$1****", options: .regularExpression)
                .replacingOccurrences(of: "(idToken\":\")\\S+", with: "$1****\"", options: .regularExpression)

            wg_log(.info, message: "Filtered Response JSON: \(filteredMessage)")
        } else {
            wg_log(.info, message: "Response has no data or data could not be decoded as UTF8")
        }
    }

    func request(_ request: Request, didCompleteTask task: URLSessionTask, with error: Error?) {
        wg_log(.info, message: "Request task completed for: \(request.description), error: \(error?.localizedDescription ?? "none")")
    }

    func requestDidFinish(_ request: Request) {
        wg_log(.info, message: "Request Finished: \(request.description)")
    }

    func requestDidFail(_ request: Request, withError error: Error) {
        wg_log(.error, message: " Request Failed: \(error.localizedDescription)")
    }
}

// MARK: - Auth Interceptor
class AuthInterceptor: RequestInterceptor {
    private let excludedUrls: [String] = ["\(ApiClient.BASE_URL)auth/refresh"]

    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        if excludedUrls.contains(where: { urlRequest.url?.absoluteString.starts(with: $0) == true }) {
            completion(.success(urlRequest))
            return
        }

        completion(.success(urlRequest))
    }

    func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
        guard let response = request.task?.response as? HTTPURLResponse, response.statusCode == 401 else {
            completion(.doNotRetry)
            return
        }

        renewJwt { newToken in
            if let token = newToken {
                completion(.retryWithDelay(0.5))
            } else {
                completion(.doNotRetry)
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

// MARK: - ApiClient
class ApiClient {
    static let BASE_URL = "https://signal.staging.jimber.io/api/v1/"

    static let apiService: ApiService = {
        return ApiServiceImpl()
    }()
}

// MARK: - ApiService Protocol
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

// MARK: - ApiService Implementation
class ApiServiceImpl: ApiService {
    private let session: Session

    init() {
        let interceptor = AuthInterceptor()
        self.session = Session(interceptor: interceptor, eventMonitors: [CustomLogger()])
    }

    private func handleResponse<T: Decodable>(_ response: AFDataResponse<Data>, completion: @escaping (Result<T, Error>) -> Void) {
        switch response.result {
        case .success(let data):
            if let dataString = String(data: data, encoding: .utf8) {
                wg_log(.info, message: "Response Data: \(dataString)")
            } else {
                wg_log(.info, message: "Response Data: <non-UTF8 data>")
            }

            do {
                let decoded = try JSONDecoder().decode(T.self, from: data)
                completion(.success(decoded))
            } catch {
                completion(.failure(error))
            }
        case .failure(let error):
            if let data = response.data,
               let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let message = json["message"] as? String {
                wg_log(.error, message: message)
                completion(.failure(NSError(domain: "", code: response.response?.statusCode ?? 0, userInfo: [NSLocalizedDescriptionKey: message])))
            } else {
                completion(.failure(error))
            }
        }
    }

    func getUserAuthentication(type: String, data: AuthenticationApiRequest, completion: @escaping (Result<UserAuthenticationApiResult, Error>) -> Void) {
        let url = "\(ApiClient.BASE_URL)auth/verify-\(type)-id"
        session.request(url, method: .post, parameters: data, encoder: JSONParameterEncoder.default)
            .validate()
            .responseData { response in
                var completionWithCookie: ((UserAuthenticationApiResult) -> Void)? = nil
                if let headers = response.response?.allHeaderFields as? [String: String],
                   let setCookie = headers["Set-Cookie"] {
                    completionWithCookie = { var result = $0; result.authCookie = setCookie; completion(.success(result)) }
                }
                self.handleResponse(response) { (result: Result<UserAuthenticationApiResult, Error>) in
                    switch result {
                    case .success(let data): completionWithCookie?(data) ?? completion(.success(data))
                    case .failure(let error): completion(.failure(error))
                    }
                }
            }
    }

    func createDaemon(userId: Int, company: String, data: CreateDaemonApiRequest, cookies: String, completion: @escaping (Result<CreateDaemonApiResult, Error>) -> Void) {
        let url = "\(ApiClient.BASE_URL)companies/\(company)/daemons/user/\(userId)"
        session.request(url, method: .post, parameters: data, encoder: JSONParameterEncoder.default, headers: ["Cookie": cookies])
            .validate()
            .responseData { self.handleResponse($0, completion: completion) }
    }

    func deleteDaemon(daemonId: Int, company: String, authorization: String, completion: @escaping (Result<DeleteDaemonApiResult, Error>) -> Void) {
        let url = "\(ApiClient.BASE_URL)companies/\(company)/daemons-mobile/\(daemonId)"
        session.request(url, method: .delete, headers: ["Authorization": authorization])
            .validate()
            .responseData { self.handleResponse($0, completion: completion) }
    }

    func sendVerificationEmail(data: VerificationCodeApiRequest, completion: @escaping (Result<Bool, Error>) -> Void) {
        let url = "\(ApiClient.BASE_URL)auth/send-user-token-code"
        session.request(url, method: .post, parameters: data, encoder: JSONParameterEncoder.default)
            .validate()
            .responseData { self.handleResponse($0, completion: completion) }
    }

    func verifyEmailWithToken(data: AuthenticationWithVerificationCodeApiRequest, completion: @escaping (Result<UserAuthenticationApiResult, Error>) -> Void) {
        let url = "\(ApiClient.BASE_URL)auth/verify-email-token"
        session.request(url, method: .post, parameters: data, encoder: JSONParameterEncoder.default)
            .validate()
            .responseData { response in
                var completionWithCookie: ((UserAuthenticationApiResult) -> Void)? = nil
                if let headers = response.response?.allHeaderFields as? [String: String],
                   let setCookie = headers["Set-Cookie"] {
                    completionWithCookie = { var result = $0; result.authCookie = setCookie; completion(.success(result)) }
                }
                self.handleResponse(response) { (result: Result<UserAuthenticationApiResult, Error>) in
                    switch result {
                    case .success(let data): completionWithCookie?(data) ?? completion(.success(data))
                    case .failure(let error): completion(.failure(error))
                    }
                }
            }
    }

    func refreshToken(cookies: String, completion: @escaping (Result<RefreshTokenApiResult, Error>) -> Void) {
        let url = "\(ApiClient.BASE_URL)auth/refresh"
        session.request(url, method: .get, headers: ["Cookie": cookies])
            .validate()
            .responseData { self.handleResponse($0, completion: completion) }
    }

    func logout(cookies: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        let url = "\(ApiClient.BASE_URL)auth/logout"
        session.request(url, method: .post, headers: ["Cookie": cookies])
            .validate()
            .responseData { self.handleResponse($0, completion: completion) }
    }

    func getCloudControllerInformation(daemonId: Int, company: String, authorization: String, completion: @escaping (Result<NetworkControllerApiResult, Error>) -> Void) {
        let url = "\(ApiClient.BASE_URL)companies/\(company)/daemons-mobile/\(daemonId)/nc-information"
        session.request(url, method: .get, headers: ["Authorization": authorization])
            .validate()
            .responseData { self.handleResponse($0, completion: completion) }
    }
}
