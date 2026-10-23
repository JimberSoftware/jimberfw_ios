import Foundation

func saveDataToLocalStorage(cookies: String, user: User) {
    let authToken = extractCookieValue(from: cookies, for: "Authentication")
    let refreshToken = extractCookieValue(from: cookies, for: "Refresh")

    let sharedStorage = SharedStorage.shared

    sharedStorage.saveCurrentUser(user: user)
    sharedStorage.saveRefreshToken(refreshToken ?? "")
    sharedStorage.saveAuthenticationToken(authToken ?? "")
}

func updateStoredCookies(fromSetCookie header: String?) {
    guard let header = header else { return }

    let sharedStorage = SharedStorage.shared

    if let authenticationToken = extractCookieValue(from: header, for: "Authentication") {
        sharedStorage.saveAuthenticationToken(authenticationToken)
    }
    if let refreshToken = extractCookieValue(from: header, for: "Refresh") {
        sharedStorage.saveRefreshToken(refreshToken)
    }
}
