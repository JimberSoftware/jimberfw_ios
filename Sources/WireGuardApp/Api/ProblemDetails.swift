import Foundation

/// RFC 9457 "Problem Details" body.
///
/// The SASE API returns this shape for every HTTP error, with
/// `Content-Type: application/problem+json`. Only `type`, `title` and `status`
/// are guaranteed by the RFC; the API makes `detail` optional and Prisma
/// conflicts can carry nothing but `errors`, so every field is optional here.
struct ProblemDetails: Decodable {
    struct FieldError: Decodable {
        let code: String?
        let detail: String?
        let field: String?
        let pointer: String?
    }

    let type: String?
    let title: String?
    let status: Int?
    let detail: String?
    let instance: String?
    let code: String?
    let correlationId: String?
    let errors: [FieldError]?

    /// `urn:jimber:problem:not-found` -> `not-found`; `about:blank` -> `nil`.
    var typeSlug: String? {
        guard let type = type, type != "about:blank" else { return nil }
        return type.split(separator: ":").last.map(String.init)
    }

    /// `{}` decodes successfully but is not a problem document.
    var hasContent: Bool {
        type != nil || title != nil || status != nil || detail != nil || !(errors ?? []).isEmpty
    }
}

/// An error returned by the SASE API, or a transport failure while calling it.
///
/// `statusCode` is the HTTP status when a response was received, and `0` for
/// connection failures. User-facing text comes from `detail`, then from the
/// field errors, and only then from a status-based fallback, so a proxy's HTML
/// error page can never leak into the UI.
struct APIError: LocalizedError {
    let statusCode: Int
    let problem: ProblemDetails?
    let underlyingDescription: String?

    var errorDescription: String? {
        if let detail = problem?.detail?.trimmedNonEmpty {
            return detail
        }
        if let fieldText = fieldErrorText {
            return fieldText
        }
        if statusCode == 0, let underlying = underlyingDescription?.trimmedNonEmpty {
            return underlying
        }
        if statusCode != 0 {
            return APIError.defaultMessage(for: statusCode)
        }
        if let title = problem?.title?.trimmedNonEmpty {
            return title
        }
        return APIError.defaultMessage(for: statusCode)
    }

    /// Machine-readable category, e.g. `not-found`. `nil` for legacy bodies and
    /// transport errors.
    var typeSlug: String? { problem?.typeSlug }
    var type: String? { problem?.type }
    var correlationId: String? { problem?.correlationId }
    var fieldErrors: [ProblemDetails.FieldError] { problem?.errors ?? [] }

    var isNetworkError: Bool { statusCode == 0 }
    var isUnauthorized: Bool { statusCode == 401 || typeSlug == "unauthorized" }
    var isForbidden: Bool { statusCode == 403 || typeSlug == "forbidden" }
    var isNotFound: Bool { statusCode == 404 || typeSlug == "not-found" }
    var isServerError: Bool { statusCode >= 500 }

    /// The daemon no longer exists for this account: deleted in SASE, or its
    /// signing key is no longer accepted.
    var isDaemonGone: Bool {
        isForbidden || isNotFound
    }

    /// Detail for a form field. Matches `email` against `email`, against a
    /// Prisma index such as `user_email_key`, and against `/email` pointers.
    func message(forField field: String) -> String? {
        let needle = field.lowercased()
        for error in fieldErrors {
            guard let detail = error.detail?.trimmedNonEmpty else { continue }
            if let errorField = error.field?.lowercased(),
               errorField == needle || errorField.contains(needle) {
                return detail
            }
            if let pointer = error.pointer?.lowercased(), pointer.hasSuffix("/\(needle)") {
                return detail
            }
        }
        return nil
    }

    /// Safe for the log file: status and machine-readable category only.
    var logDescription: String {
        "API error status=\(statusCode) type=\(typeSlug ?? "-") correlation=\(correlationId ?? "-")"
    }

    private var fieldErrorText: String? {
        let details = fieldErrors.compactMap { $0.detail?.trimmedNonEmpty }
        guard !details.isEmpty else { return nil }
        return details.joined(separator: "\n")
    }

    static func defaultMessage(for status: Int) -> String {
        switch status {
        case 0: return "Could not reach the server. Check your internet connection."
        case 400: return "The request could not be processed."
        case 401: return "Authentication failed. Please sign in again."
        case 403: return "You do not have permission to perform this action."
        case 404: return "The requested item could not be found."
        case 409: return "This action conflicts with existing data."
        case 422: return "Some of the entered details are invalid."
        case 429: return "Too many requests. Please try again later."
        case 500...599: return "The server encountered an error. Please try again later."
        default: return "Something went wrong. Please try again."
        }
    }
}

extension APIError {
    init(httpResponse: HTTPURLResponse?, data: Data?, underlying: Error?) {
        let httpStatus = httpResponse?.statusCode ?? 0
        let decoded = data.flatMap { try? JSONDecoder().decode(ProblemDetails.self, from: $0) }
        let problem = decoded?.hasContent == true ? decoded : nil
        let resolved = problem ?? APIError.legacyProblem(from: data)

        self.init(
            statusCode: resolved?.status ?? httpStatus,
            problem: resolved,
            underlyingDescription: underlying?.localizedDescription
        )
    }

    /// Pre-RFC-9457 body (`statusCode`, `error`, `message`), kept so a new
    /// client still talks to an older server during the rollout.
    private static func legacyProblem(from data: Data?) -> ProblemDetails? {
        guard let data = data,
              let object = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return nil
        }

        let status = object["statusCode"] as? Int
        let title = object["error"] as? String
        var detail: String?
        var errors: [ProblemDetails.FieldError]?

        if let message = object["message"] as? String {
            detail = message
        } else if let message = object["message"] as? [String: Any] {
            // Legacy field exception: { message: { field: "..." }, type: "field-exception" }
            errors = [ProblemDetails.FieldError(code: nil, detail: "", field: message["field"] as? String, pointer: nil)]
        } else if let messages = object["message"] as? [String] {
            errors = messages.map { ProblemDetails.FieldError(code: nil, detail: $0, field: nil, pointer: nil) }
        }

        guard title != nil || detail != nil || errors != nil else { return nil }

        return ProblemDetails(
            type: nil,
            title: title,
            status: status,
            detail: detail,
            instance: nil,
            code: nil,
            correlationId: nil,
            errors: errors
        )
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension Error {
    /// Log-safe description. Server-provided text (`detail`) can echo user
    /// input, so for API errors only the status and category are used.
    var safeLogDescription: String {
        (self as? APIError)?.logDescription ?? localizedDescription
    }
}
