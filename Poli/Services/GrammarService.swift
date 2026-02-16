import Foundation

/// High-level grammar correction service.
///
/// Validates input constraints before delegating to ``AIService`` for the
/// actual server-side correction.
final class GrammarService {

    // MARK: - Singleton

    static let shared = GrammarService()

    // MARK: - Dependencies

    private let aiService: AIService

    // MARK: - Init

    private init(aiService: AIService = .shared) {
        self.aiService = aiService
    }

    // MARK: - Public API

    /// Corrects the grammar of the given text via the Poli backend.
    ///
    /// - Parameter text: The text to correct.
    /// - Returns: A tuple with the corrected text and a short explanation of
    ///   the changes that were made.
    /// - Throws: ``PoliError/textTooLong(limit:)`` when the input exceeds the
    ///   allowed character limit, or any ``PoliError`` propagated from the
    ///   network layer.
    func correct(text: String) async throws -> AIService.CorrectionResult {
        let maxLength = EntitlementManager.shared.currentTier.maxTextLength

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PoliError.emptyClipboard
        }

        guard text.count <= maxLength else {
            throw PoliError.textTooLong(limit: maxLength)
        }

        return try await aiService.correctGrammar(text: text)
    }
}
