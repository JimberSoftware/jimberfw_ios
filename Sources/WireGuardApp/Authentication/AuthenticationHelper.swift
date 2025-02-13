import Foundation

func extractToken(from: String, key: String) -> String? {
    let cookies = from.split(separator: ";")

    for cookie in cookies {
        let cookieString = cookie.trimmingCharacters(in: .whitespaces)
        if cookieString.hasPrefix("\(key)=") {
            return cookieString.replacingOccurrences(of: "\(key)=", with: "")
        }
    }
    return nil
}
