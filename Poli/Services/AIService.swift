import Foundation

/// HTTP client for the **Poli Laravel backend** API.
///
/// All AI processing (grammar correction, translation) is performed on the
/// server side. This service simply sends text to the backend and decodes the
/// structured responses. It does **not** communicate with the Anthropic API
/// directly.
///
/// Authentication is handled via a Bearer token stored in the Keychain under
/// the key `"auth_token"`.
final class AIService {

    // MARK: - Singleton

    static let shared = AIService()

    // MARK: - Configuration

    /// Base URL of the Poli backend, read from `Constants`.
    private let baseURL: URL = Constants.apiBaseURL

    /// The authentication token for the backend, persisted in the Keychain.
    var authToken: String? {
        get { KeychainHelper.shared.read(key: Constants.keychainAuthTokenKey) }
        set {
            if let value = newValue {
                KeychainHelper.shared.save(key: Constants.keychainAuthTokenKey, value: value)
            } else {
                KeychainHelper.shared.delete(key: Constants.keychainAuthTokenKey)
            }
        }
    }

    // MARK: - Shared URLSession

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {}

    // MARK: - Request / Response DTOs

    /// Body sent to `POST /api/correct`.
    private struct CorrectionRequest: Encodable {
        let text: String
        let user_language: String
    }

    /// Body sent to `POST /api/translate`.
    private struct TranslationRequest: Encodable {
        let text: String
        let target_language: String
        let user_language: String
    }

    /// Wrapper for backend error payloads (`{"message": "..."}`)
    private struct APIErrorBody: Decodable {
        let message: String?
    }

    /// Extracts `remaining_actions` from any backend JSON response.
    private struct BackendMetadata: Decodable {
        let remaining_actions: Int?
    }

    // MARK: - Public Result Types

    /// A single grammar/spelling error with its correction and rule explanation.
    struct CorrectionError: Codable, Equatable {
        let original: String
        let correction: String
        let rule: String
    }

    /// The response returned by the grammar correction endpoint.
    struct CorrectionResult: Codable {
        let corrected: String
        let explanation: String
        let errors: [CorrectionError]
        let language: String?
    }

    /// A pedagogical tip about the translation (false friends, idioms, grammar rules).
    struct TranslationTip: Codable, Equatable {
        let term: String
        let tip: String
    }

    /// The response returned by the translation endpoint.
    struct TranslationResult: Codable {
        let translated: String
        let sourceLanguage: String
        let tips: [TranslationTip]

        private enum CodingKeys: String, CodingKey {
            case translated
            case sourceLanguage = "source_language"
            case tips
        }
    }

    // MARK: - Public API

    /// Sends text to the backend for grammar correction.
    ///
    /// - Parameter text: The text to correct.
    /// - Returns: A ``CorrectionResult`` containing the corrected text and an
    ///   explanation of the changes.
    /// - Throws: ``PoliError`` on network, authentication, or server errors.
    func correctGrammar(text: String) async throws -> CorrectionResult {
        let url = baseURL.appendingPathComponent("api/correct")
        let userLang = UserDefaults.standard.string(forKey: Constants.UserDefaultsKey.userLanguage) ?? "fr"
        let body = CorrectionRequest(text: text, user_language: userLang)
        return try await performRequest(url: url, body: body)
    }

    /// Sends text to the backend for translation.
    ///
    /// - Parameters:
    ///   - text: The text to translate.
    ///   - targetLanguage: The language to translate into.
    /// - Returns: A ``TranslationResult`` containing the translated text and
    ///   the detected source language.
    /// - Throws: ``PoliError`` on network, authentication, or server errors.
    func translate(text: String, targetLanguage: SupportedLanguage) async throws -> TranslationResult {
        let url = baseURL.appendingPathComponent("api/translate")
        let userLang = UserDefaults.standard.string(forKey: Constants.UserDefaultsKey.userLanguage) ?? "fr"
        let body = TranslationRequest(text: text, target_language: targetLanguage.rawValue, user_language: userLang)
        return try await performRequest(url: url, body: body)
    }

    // MARK: - Private Helpers

    /// Builds an authenticated `URLRequest`, executes it, validates the HTTP
    /// status, and decodes the JSON response into the expected type.
    private func performRequest<RequestBody: Encodable, ResponseBody: Decodable>(
        url: URL,
        body: RequestBody
    ) async throws -> ResponseBody {
        guard let token = authToken, !token.isEmpty else {
            throw PoliError.unauthorized
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        request.httpBody = try encoder.encode(body)

        #if DEBUG
        print("[API] POST \(url.absoluteString)")
        #endif
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
            #if DEBUG
            print("[API] Response: \(String(data: data, encoding: .utf8) ?? "<binary>")")
            #endif
        } catch let urlError as URLError {
            switch urlError.code {
            case .timedOut:
                throw PoliError.networkError("The request timed out. Please try again.")
            case .notConnectedToInternet, .networkConnectionLost:
                throw PoliError.networkError("No internet connection.")
            default:
                throw PoliError.networkError(urlError.localizedDescription)
            }
        } catch {
            throw PoliError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PoliError.networkError("Invalid server response.")
        }

        // Always sync remaining actions from backend (source of truth),
        // even on error responses (e.g. 429 returns remaining_actions: 0).
        if let metadata = try? decoder.decode(BackendMetadata.self, from: data),
           let remaining = metadata.remaining_actions {
            await MainActor.run {
                UsageTracker.shared.syncFromBackend(remainingActions: remaining)
            }
        }

        // Handle non-success status codes.
        switch httpResponse.statusCode {
        case 200...299:
            break // success path continues below
        case 401:
            throw PoliError.unauthorized
        case 429:
            throw PoliError.usageLimitReached
        case 403:
            throw PoliError.notSubscribed
        default:
            let errorMessage = parseErrorMessage(from: data)
                ?? "Unexpected error (HTTP \(httpResponse.statusCode))."
            throw PoliError.apiError(
                statusCode: httpResponse.statusCode,
                message: errorMessage
            )
        }

        // Decode the successful response.
        do {
            let result = try decoder.decode(ResponseBody.self, from: data)
            return result
        } catch {
            throw PoliError.emptyResponse
        }
    }

    /// Attempts to extract a human-readable error message from a JSON error
    /// body returned by the backend.
    private func parseErrorMessage(from data: Data) -> String? {
        try? decoder.decode(APIErrorBody.self, from: data).message
    }
}
