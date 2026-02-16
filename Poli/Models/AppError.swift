import Foundation

/// Typed error cases for the Poli application.
enum PoliError: LocalizedError {

    /// A network-level failure (no connectivity, DNS resolution, etc.).
    case networkError(String)

    /// The backend returned a non-success HTTP status code.
    case apiError(statusCode: Int, message: String)

    /// The backend returned a successful response but the body was empty or unparseable.
    case emptyResponse

    /// The clipboard contained no text when an action was triggered.
    case emptyClipboard

    /// The usage limit has been reached (lifetime for free, daily for paid).
    case usageLimitReached

    /// The requested feature requires an active Pro subscription.
    case notSubscribed

    /// The input text exceeds the allowed character limit.
    case textTooLong(limit: Int)

    /// The stored authentication token is missing or invalid.
    case unauthorized

    // MARK: - LocalizedError

    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return String(format: String(localized: "error.network"), message)
        case .apiError(let statusCode, let message):
            return String(format: String(localized: "error.api"), statusCode, message)
        case .emptyResponse:
            return String(localized: "error.empty_response")
        case .emptyClipboard:
            return String(localized: "error.empty_clipboard")
        case .usageLimitReached:
            return String(localized: "error.usage_limit")
        case .notSubscribed:
            return String(localized: "error.not_subscribed")
        case .textTooLong(let limit):
            return String(format: String(localized: "error.text_too_long"), limit)
        case .unauthorized:
            return String(localized: "error.unauthorized")
        }
    }
}
