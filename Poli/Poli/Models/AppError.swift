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

    /// The free-tier daily usage limit has been reached.
    case dailyLimitReached

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
            return "Network error: \(message)"
        case .apiError(let statusCode, let message):
            return "API error (\(statusCode)): \(message)"
        case .emptyResponse:
            return "The server returned an empty response."
        case .emptyClipboard:
            return "Nothing in the clipboard."
        case .dailyLimitReached:
            return "Daily usage limit reached. Upgrade to Pro for unlimited access."
        case .notSubscribed:
            return "This feature requires a Pro subscription."
        case .textTooLong(let limit):
            return "The text is too long. Maximum allowed: \(limit) characters."
        case .unauthorized:
            return "Authentication required. Please sign in again."
        }
    }
}
