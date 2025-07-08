import Foundation

func isValidMobileHostname(_ hostname: String) -> (Bool, String?) {
    // Check if string contains only alphanumeric characters and hyphens
    do {
        let regex = try NSRegularExpression(pattern: "^[a-zA-Z0-9-]+$")
        let range = NSRange(location: 0, length: hostname.utf16.count)
        if regex.firstMatch(in: hostname, options: [], range: range) == nil {
            return (false, "Hostname may only contain letters, digits, and hyphens.")
        }
    } catch {
        return (false, "Internal error: invalid regex.")
    }

    // Check that there is at most one hyphen
    if hostname.filter({ $0 == "-" }).count > 1 {
        return (false, "Hostname may contain at most one hyphen.")
    }

    // Check that it doesn't start with a hyphen
    if hostname.hasPrefix("-") {
        return (false, "Hostname may not start with a hyphen.")
    }

    // Length must be between 2 and 63 characters
    if hostname.count < 2 || hostname.count > 63 {
        return (false, "Hostname length must be between 2 and 63 characters.")
    }

    // Check if the first character is a digit
    if let firstChar = hostname.first, firstChar.isNumber {
        return (false, "Hostname may not start with a digit.")
    }

    return (true, nil)
}
