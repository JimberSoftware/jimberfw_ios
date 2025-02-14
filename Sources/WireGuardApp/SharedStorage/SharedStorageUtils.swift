import Foundation

func saveDataToLocalStorage(cookies: String, user: User) {
    let authToken = extractCookieValue(from: cookies, for: "Authentication")
    let refreshToken = extractCookieValue(from: cookies, for: "Refresh")

    let sharedStorage = SharedStorage.shared

    sharedStorage.saveCurrentUser(user: user)
    sharedStorage.saveRefreshToken(refreshToken ?? "")
    sharedStorage.saveAuthenticationToken(authToken ?? "")
}

func getCookieString() -> String {
    let sharedStorage = SharedStorage.shared
    let authToken = sharedStorage.getAuthenticationToken()!
    let refreshToken = sharedStorage.getRefreshToken()!

    return "Authentication=\(authToken); Refresh=\(refreshToken)"
}
