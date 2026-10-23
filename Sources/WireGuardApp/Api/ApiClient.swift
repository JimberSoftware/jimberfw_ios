import Foundation
import Alamofire

// MARK: - Custom Logger
/// Logs request/response metadata only.
///
/// Bodies, query strings and headers are deliberately never logged: they carry
/// auth cookies, JWTs and VPN configuration. The in-app log file is exportable,
/// so anything written here must be safe to hand to a third party.
final class CustomLogger: EventMonitor {
    let queue = DispatchQueue(label: "com.wireguard.ios")

    private func sanitizedURL(_ url: URL?) -> String {
        guard let url = url else { return "<unknown>" }
        // Drop query string and fragment: they can contain credentials.
        return "\(url.host ?? "<unknown>")\(url.path)"
    }

    func requestDidResume(_ request: Request) {
        let method = request.request?.httpMethod ?? "N/A"
        wg_log(.info, message: "Request Started: \(method) \(sanitizedURL(request.request?.url))")
    }

    func request(_ request: DataRequest, didParseResponse response: DataResponse<Data?, AFError>) {
        let status = response.response.map { String($0.statusCode) } ?? "no response"
        let byteCount = response.data?.count ?? 0
        wg_log(.info, message: "Response: \(status), \(byteCount) bytes")
    }

    func request(_ request: Request, didCompleteTask task: URLSessionTask, with error: Error?) {
        if let error = error {
            wg_log(.info, message: "Request task failed: \(error.localizedDescription)")
        }
    }

    func requestDidFinish(_ request: Request) {
        wg_log(.info, message: "Request Finished: \(sanitizedURL(request.request?.url))")
    }

    func requestDidFail(_ request: Request, withError error: Error) {
        wg_log(.error, message: "Request Failed: \(error.localizedDescription)")
    }
}

// MARK: - Redirect Policy
/// Only follows redirects that stay on the same host, so credentials and API
/// responses can never be redirected to another origin.
struct SameHostRedirectHandler: RedirectHandler {
    func task(_ task: URLSessionTask,
              willBeRedirectedTo request: URLRequest,
              for response: HTTPURLResponse,
              completion: @escaping (URLRequest?) -> Void) {
        guard let originalHost = response.url?.host?.lowercased(),
              let redirectHost = request.url?.host?.lowercased(),
              originalHost == redirectHost else {
            wg_log(.error, message: "Refusing cross-host redirect")
            completion(nil)
            return
        }
        completion(request)
    }
}

// MARK: - Auth Interceptor
final class AuthInterceptor: RequestInterceptor {
    private static func isNonRenewableAuthEndpoint(_ path: String) -> Bool {
        path.contains("/auth/verify-") ||
        path.contains("/auth/send-user-token-code") ||
        path.contains("/auth/refresh")
    }

    func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
        // If the status code is not 401, don't retry.
        guard let response = request.task?.response as? HTTPURLResponse, response.statusCode == 401 else {
            completion(.doNotRetry)
            return
        }

        // A 401 from a login/verification endpoint means bad credentials or an
        // expired code, not an expired session. Refreshing there would hide the
        // server's message and waste a request. Logout is the exception: if the
        // access cookie expired, refreshing first lets the server revoke the
        // refresh token properly.
        if let path = request.request?.url?.path, AuthInterceptor.isNonRenewableAuthEndpoint(path) {
            completion(.doNotRetry)
            return
        }

        // Retry at most once per request.
        guard request.retryCount == 0 else {
            completion(.doNotRetry)
            return
        }

        // Renew the JWT token
        renewJwt { newToken in
            if newToken != nil {
                completion(.retryWithDelay(2))  // Retry the request after 2 seconds
            } else {
                completion(.doNotRetry)  // Don't retry if JWT renewal failed
            }
        }
    }

    private func renewJwt(completion: @escaping (String?) -> Void) {
        ApiClient.apiService.refreshToken { result in
            switch result {
            case .success(let response):
                // The server rotates the Authentication cookie on refresh. URLSession
                // already stored it in the session's in-memory cookie jar (so the
                // retried request sends the new one); persist it for the next launch.
                updateStoredCookies(fromSetCookie: response.authCookie)
                completion(response.accessToken)
            case .failure:
                completion(nil)
            }
        }
    }
}

// MARK: - ApiClient
class ApiClient {
    static let BASE_URL = Config.API_BASE_URL

    static let apiService: ApiService = {
        // Credentials and VPN configuration travel over this connection, so refuse
        // anything that is not TLS.
        guard Config.API_BASE_URL.lowercased().hasPrefix("https://") else {
            fatalError("API_BASE_URL must use https:// (got \(Config.API_BASE_URL))")
        }
        return ApiServiceImpl()
    }()
}

// MARK: - ApiService Protocol
protocol ApiService {
    func getUserAuthentication(type: String, data: AuthenticationApiRequest, completion: @escaping (Result<UserAuthenticationApiResult, Error>) -> Void)
    func createDaemon(userId: Int, company: String, data: CreateDaemonApiRequest, completion: @escaping (Result<CreateDaemonApiResult, Error>) -> Void)
    func deleteDaemon(daemonId: Int, company: String, authorization: String, completion: @escaping (Result<DeleteDaemonApiResult, Error>) -> Void)
    func getDaemonInformation(daemonId: Int, company: String, authorization: String, completion: @escaping (Result<GetDaemonInformationApiResult, Error>) -> Void)
    func sendVerificationEmail(data: VerificationCodeApiRequest, completion: @escaping (Result<Bool, Error>) -> Void)
    func verifyEmailWithToken(data: AuthenticationWithVerificationCodeApiRequest, completion: @escaping (Result<UserAuthenticationApiResult, Error>) -> Void)
    func refreshToken(completion: @escaping (Result<RefreshTokenApiResult, Error>) -> Void)
    func logout(completion: @escaping (Result<Bool, Error>) -> Void)
    func getCloudControllerInformation(daemonId: Int, company: String, authorization: String, completion: @escaping (Result<NetworkControllerApiResult, Error>) -> Void)
    func clearSessionCookies()
}

// MARK: - ApiService Implementation
class ApiServiceImpl: ApiService {
    private let session: Session
    private let cookieStorage: HTTPCookieStorage?

    init() {
        let configuration = ApiServiceImpl.makeConfiguration()
        self.cookieStorage = configuration.httpCookieStorage

        let interceptor = AuthInterceptor()
        self.session = Session(
            configuration: configuration,
            interceptor: interceptor,
            redirectHandler: SameHostRedirectHandler(),
            eventMonitors: [CustomLogger()]
        )
    }

    /// Ephemeral session: no disk cache and no persistent cookie jar.
    ///
    /// Cookies are kept in memory by URLSession. That matters for the 401 flow:
    /// `/auth/refresh` rotates the Authentication cookie, and the retried request
    /// must send that new value. Alamofire reuses the original URLRequest, so a
    /// manually added `Cookie` header would stay stale; letting URLSession attach
    /// cookies to each new task avoids that.
    private static func makeConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpShouldSetCookies = true
        configuration.httpCookieAcceptPolicy = .always
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60

        seedCookies(in: configuration.httpCookieStorage)
        return configuration
    }

    /// Puts the session cookies stored on disk (UserDefaults) into the in-memory
    /// jar after an app launch. Responses then keep them up to date.
    private static func seedCookies(in storage: HTTPCookieStorage?) {
        guard let storage = storage, let host = URL(string: ApiClient.BASE_URL)?.host else { return }

        let tokens = [
            ("Authentication", SharedStorage.shared.getAuthenticationToken()),
            ("Refresh", SharedStorage.shared.getRefreshToken())
        ]

        for (name, value) in tokens {
            guard let value = value, !value.isEmpty else { continue }
            let properties: [HTTPCookiePropertyKey: Any] = [
                .name: name,
                .value: value,
                .domain: host,
                .path: "/",
                .secure: "TRUE"
            ]
            guard let cookie = HTTPCookie(properties: properties) else { continue }
            storage.setCookie(cookie)
        }
    }

    func clearSessionCookies() {
        cookieStorage?.removeCookies(since: .distantPast)
    }

    private func handleResponse<T: Decodable>(_ response: AFDataResponse<Data>, completion: @escaping (Result<T, Error>) -> Void) {
        switch response.result {
        case .success(let data):
            do {
                let decoded = try JSONDecoder().decode(T.self, from: data)
                completion(.success(decoded))
            } catch {
                // Do not log the decoding error or payload: both can echo response values.
                wg_log(.error, message: "Unable to decode API response (\(data.count) bytes)")
                completion(.failure(error))
            }
        case .failure(let error):
            let apiError = APIError(httpResponse: response.response, data: response.data, underlying: error)
            wg_log(.error, message: apiError.logDescription)
            completion(.failure(apiError))
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

    func createDaemon(userId: Int, company: String, data: CreateDaemonApiRequest, completion: @escaping (Result<CreateDaemonApiResult, Error>) -> Void) {
        let url = "\(ApiClient.BASE_URL)companies/\(company)/daemons/user/\(userId)"
        session.request(url, method: .post, parameters: data, encoder: JSONParameterEncoder.default)
            .validate()
            .responseData { self.handleResponse($0, completion: completion) }
    }

    func deleteDaemon(daemonId: Int, company: String, authorization: String, completion: @escaping (Result<DeleteDaemonApiResult, Error>) -> Void) {
        let url = "\(ApiClient.BASE_URL)companies/\(company)/daemons-mobile/\(daemonId)"
        session.request(url, method: .delete, headers: ["Authorization": authorization])
            .validate()
            .responseData { self.handleResponse($0, completion: completion) }
    }

    func getDaemonInformation(daemonId: Int, company: String, authorization: String, completion: @escaping (Result<GetDaemonInformationApiResult, Error>) -> Void) {
        let url = "\(ApiClient.BASE_URL)companies/\(company)/daemons-mobile/\(daemonId)"
        session.request(url, method: .get, headers: ["Authorization": authorization])
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

    func refreshToken(completion: @escaping (Result<RefreshTokenApiResult, Error>) -> Void) {
        let url = "\(ApiClient.BASE_URL)auth/refresh"
        session.request(url, method: .get)
            .validate()
            .responseData { response in
                var completionWithCookie: ((RefreshTokenApiResult) -> Void)? = nil
                if let headers = response.response?.allHeaderFields as? [String: String],
                   let setCookie = headers["Set-Cookie"] {
                    completionWithCookie = { var result = $0; result.authCookie = setCookie; completion(.success(result)) }
                }
                self.handleResponse(response) { (result: Result<RefreshTokenApiResult, Error>) in
                    switch result {
                    case .success(let data): completionWithCookie?(data) ?? completion(.success(data))
                    case .failure(let error): completion(.failure(error))
                    }
                }
            }
    }

    func logout(completion: @escaping (Result<Bool, Error>) -> Void) {
        let url = "\(ApiClient.BASE_URL)auth/logout"
        session.request(url, method: .post)
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
