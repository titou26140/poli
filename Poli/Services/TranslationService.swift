import Foundation

/// High-level translation service.
///
/// Validates input constraints and optionally detects the source language
/// on-device before delegating to ``AIService`` for server-side translation.
final class TranslationService {

    // MARK: - Singleton

    static let shared = TranslationService()

    // MARK: - Dependencies

    private let aiService: AIService
    private let languageDetection: LanguageDetectionService

    // MARK: - Init

    private init(
        aiService: AIService = .shared,
        languageDetection: LanguageDetectionService = .shared
    ) {
        self.aiService = aiService
        self.languageDetection = languageDetection
    }

    // MARK: - Public API

    /// Translates the given text into the specified target language via the
    /// Poli backend.
    ///
    /// The source language is automatically detected on-device using
    /// ``LanguageDetectionService`` and is also returned by the backend in the
    /// response.
    ///
    /// - Parameters:
    ///   - text: The text to translate.
    ///   - targetLanguage: The language to translate into.
    /// - Returns: A tuple with the translated text and the ISO 639-1 code of
    ///   the detected source language.
    /// - Throws: ``PoliError/textTooLong(limit:)`` when the input exceeds the
    ///   allowed character limit, or any ``PoliError`` propagated from the
    ///   network layer.
    func translate(
        text: String,
        targetLanguage: SupportedLanguage
    ) async throws -> AIService.TranslationResult {
        let maxLength = EntitlementManager.shared.currentTier.maxTextLength

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PoliError.emptyClipboard
        }

        guard text.count <= maxLength else {
            throw PoliError.textTooLong(limit: maxLength)
        }

        var result = try await aiService.translate(
            text: text,
            targetLanguage: targetLanguage
        )

        // Fall back to local NLLanguageRecognizer when the backend does not
        // provide a source language.
        if result.sourceLanguage.isEmpty {
            result = AIService.TranslationResult(
                translated: result.translated,
                sourceLanguage: languageDetection.detect(text: text),
                tips: result.tips
            )
        }

        return result
    }
}
