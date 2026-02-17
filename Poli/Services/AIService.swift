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

    // MARK: - Public Result Types

    /// A single grammar/spelling error with its correction and rule explanation.
    struct CorrectionError: Codable, Equatable, Identifiable {
        let original: String
        let correction: String
        let rule: String

        var id: String { "\(original)-\(correction)" }
    }

    /// The response returned by the grammar correction endpoint.
    struct CorrectionResult: Codable {
        let corrected: String
        let explanation: String
        let errors: [CorrectionError]
        let language: String?
    }

    /// A pedagogical tip about the translation (false friends, idioms, grammar rules).
    struct TranslationTip: Codable, Equatable, Identifiable {
        let term: String
        let tip: String

        var id: String { "\(term)-\(tip)" }
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
        let userLang = UserDefaults.standard.string(forKey: Constants.UserDefaultsKey.userLanguage) ?? "fr"
        let body = CorrectionRequest(text: text, user_language: userLang)
        return try await APIClient.shared.request(path: "api/correct", body: body)
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
        let userLang = UserDefaults.standard.string(forKey: Constants.UserDefaultsKey.userLanguage) ?? "fr"
        let body = TranslationRequest(text: text, target_language: targetLanguage.rawValue, user_language: userLang)
        return try await APIClient.shared.request(path: "api/translate", body: body)
    }
}
