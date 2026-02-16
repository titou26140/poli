import Foundation

/// Represents the available UI languages for the Poli application.
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case french = "fr"
    case italian = "it"
    case portuguese = "pt-PT"
    case spanish = "es"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english:    return "English"
        case .french:     return "Français"
        case .italian:    return "Italiano"
        case .portuguese: return "Português"
        case .spanish:    return "Español"
        }
    }

    var flag: String {
        switch self {
        case .english:    return "\u{1F1EC}\u{1F1E7}"
        case .french:     return "\u{1F1EB}\u{1F1F7}"
        case .italian:    return "\u{1F1EE}\u{1F1F9}"
        case .portuguese: return "\u{1F1F5}\u{1F1F9}"
        case .spanish:    return "\u{1F1EA}\u{1F1F8}"
        }
    }

    /// Detects the best matching AppLanguage from the current system locale.
    static var detected: AppLanguage {
        guard let langCode = Locale.current.language.languageCode?.identifier else {
            return .english
        }
        switch langCode {
        case "fr": return .french
        case "it": return .italian
        case "pt": return .portuguese
        case "es": return .spanish
        default:   return .english
        }
    }
}
