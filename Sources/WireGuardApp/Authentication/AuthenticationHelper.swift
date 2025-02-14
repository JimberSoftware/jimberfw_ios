import Foundation

func extractCookieValue(from header: String, for key: String) -> String? {
    let cookies = header.components(separatedBy: ", ")

    for cookie in cookies {
        if cookie.starts(with: "\(key)=") {
            return cookie.replacingOccurrences(of: "\(key)=", with: "").components(separatedBy: ";").first
        }
    }
    return nil
}
