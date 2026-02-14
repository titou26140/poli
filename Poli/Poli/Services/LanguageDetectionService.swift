import Foundation
import NaturalLanguage

/// Uses Apple's NaturalLanguage framework (NLLanguageRecognizer) to detect the
/// language of a given text locally on-device, with no network call required.
final class LanguageDetectionService {

    // MARK: - Singleton

    static let shared = LanguageDetectionService()

    // MARK: - Private

    private let recognizer = NLLanguageRecognizer()

    private init() {}

    // MARK: - Public API

    /// Detects the dominant language of the given text.
    ///
    /// - Parameter text: The text to analyze.
    /// - Returns: An ISO 639-1 language code (e.g. `"en"`, `"fr"`), or
    ///   `"unknown"` when the language cannot be determined.
    func detect(text: String) -> String {
        recognizer.reset()
        recognizer.processString(text)
        return recognizer.dominantLanguage?.rawValue ?? "unknown"
    }

    /// Detects the dominant language together with a confidence score.
    ///
    /// - Parameter text: The text to analyze.
    /// - Returns: A tuple containing the ISO 639-1 language code and the
    ///   confidence value (0.0 ... 1.0). Returns `("unknown", 0.0)` when the
    ///   language cannot be determined.
    func detectWithConfidence(text: String) -> (language: String, confidence: Double) {
        recognizer.reset()
        recognizer.processString(text)

        guard let dominant = recognizer.dominantLanguage else {
            return ("unknown", 0.0)
        }

        let hypotheses = recognizer.languageHypotheses(withMaximum: 1)
        let confidence = hypotheses[dominant] ?? 0.0

        return (dominant.rawValue, confidence)
    }
}
