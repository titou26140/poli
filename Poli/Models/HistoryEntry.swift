import Foundation

struct HistoryEntry: Codable, Identifiable, Equatable {

    let serverId: Int
    let type: String
    let originalText: String
    let resultText: String
    let explanation: String?
    let errors: [AIService.CorrectionError]?
    let language: String?
    let sourceLanguage: String?
    let targetLanguage: String?
    let tips: [AIService.TranslationTip]?
    var isFavorite: Bool
    let createdAt: Date

    var id: String { "\(type)-\(serverId)" }

    var isCorrection: Bool { type == "correction" }
    var isTranslation: Bool { type == "translation" }

    private enum CodingKeys: String, CodingKey {
        case serverId = "id"
        case type
        case originalText = "original_text"
        case resultText = "result_text"
        case explanation
        case errors
        case language
        case sourceLanguage = "source_language"
        case targetLanguage = "target_language"
        case tips
        case isFavorite = "is_favorite"
        case createdAt = "created_at"
    }
}

// MARK: - Display Helpers

extension HistoryEntry {

    var iconName: String {
        isCorrection ? "checkmark.circle" : "globe"
    }

    var subtitle: String {
        if isCorrection {
            return resultText.truncated(to: 60)
        } else {
            let srcFlag = sourceLanguage.flatMap { SupportedLanguage(rawValue: $0) }?.flag ?? ""
            let tgtFlag = targetLanguage.flatMap { SupportedLanguage(rawValue: $0) }?.flag ?? ""
            return "\(srcFlag) \u{2192} \(tgtFlag)  \(resultText.truncated(to: 50))"
        }
    }

    var languageInfo: String {
        if isCorrection {
            guard let code = language else { return "" }
            let lang = SupportedLanguage(rawValue: code)
            return lang.map { "\($0.flag) \($0.displayName)" } ?? code
        } else {
            let src = sourceLanguage.flatMap { SupportedLanguage(rawValue: $0) }
            let tgt = targetLanguage.flatMap { SupportedLanguage(rawValue: $0) }
            let srcDisplay = src.map { "\($0.flag) \($0.displayName)" } ?? (sourceLanguage ?? "")
            let tgtDisplay = tgt.map { "\($0.flag) \($0.displayName)" } ?? (targetLanguage ?? "")
            return "\(srcDisplay) \u{2192} \(tgtDisplay)"
        }
    }
}
