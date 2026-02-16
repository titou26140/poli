import Foundation

/// Languages supported by Poli for translation.
///
/// The raw value is the ISO 639-1 language code.
enum SupportedLanguage: String, CaseIterable, Codable, Identifiable {
    case french     = "fr"
    case english    = "en"
    case spanish    = "es"
    case german     = "de"
    case italian    = "it"
    case portuguese = "pt"
    case dutch      = "nl"
    case russian    = "ru"
    case chinese    = "zh"
    case japanese   = "ja"
    case korean     = "ko"
    case arabic     = "ar"
    case polish     = "pl"
    case turkish    = "tr"
    case swedish    = "sv"
    case norwegian  = "no"
    case danish     = "da"
    case finnish    = "fi"
    case czech      = "cs"
    case romanian   = "ro"

    // MARK: - Identifiable

    var id: String { rawValue }

    // MARK: - Display

    /// Human-readable name of the language in its own locale.
    var displayName: String {
        switch self {
        case .french:     return "Fran\u{00E7}ais"
        case .english:    return "English"
        case .spanish:    return "Espa\u{00F1}ol"
        case .german:     return "Deutsch"
        case .italian:    return "Italiano"
        case .portuguese: return "Portugu\u{00EA}s"
        case .dutch:      return "Nederlands"
        case .russian:    return "\u{0420}\u{0443}\u{0441}\u{0441}\u{043A}\u{0438}\u{0439}"
        case .chinese:    return "\u{4E2D}\u{6587}"
        case .japanese:   return "\u{65E5}\u{672C}\u{8A9E}"
        case .korean:     return "\u{D55C}\u{AD6D}\u{C5B4}"
        case .arabic:     return "\u{0627}\u{0644}\u{0639}\u{0631}\u{0628}\u{064A}\u{0629}"
        case .polish:     return "Polski"
        case .turkish:    return "T\u{00FC}rk\u{00E7}e"
        case .swedish:    return "Svenska"
        case .norwegian:  return "Norsk"
        case .danish:     return "Dansk"
        case .finnish:    return "Suomi"
        case .czech:      return "\u{010C}e\u{0161}tina"
        case .romanian:   return "Rom\u{00E2}n\u{0103}"
        }
    }

    /// Flag emoji representing the language's primary country.
    var flag: String {
        switch self {
        case .french:     return "\u{1F1EB}\u{1F1F7}"
        case .english:    return "\u{1F1EC}\u{1F1E7}"
        case .spanish:    return "\u{1F1EA}\u{1F1F8}"
        case .german:     return "\u{1F1E9}\u{1F1EA}"
        case .italian:    return "\u{1F1EE}\u{1F1F9}"
        case .portuguese: return "\u{1F1F5}\u{1F1F9}"
        case .dutch:      return "\u{1F1F3}\u{1F1F1}"
        case .russian:    return "\u{1F1F7}\u{1F1FA}"
        case .chinese:    return "\u{1F1E8}\u{1F1F3}"
        case .japanese:   return "\u{1F1EF}\u{1F1F5}"
        case .korean:     return "\u{1F1F0}\u{1F1F7}"
        case .arabic:     return "\u{1F1F8}\u{1F1E6}"
        case .polish:     return "\u{1F1F5}\u{1F1F1}"
        case .turkish:    return "\u{1F1F9}\u{1F1F7}"
        case .swedish:    return "\u{1F1F8}\u{1F1EA}"
        case .norwegian:  return "\u{1F1F3}\u{1F1F4}"
        case .danish:     return "\u{1F1E9}\u{1F1F0}"
        case .finnish:    return "\u{1F1EB}\u{1F1EE}"
        case .czech:      return "\u{1F1E8}\u{1F1FF}"
        case .romanian:   return "\u{1F1F7}\u{1F1F4}"
        }
    }

    // MARK: - Free Tier

    /// The subset of languages available to free-tier users.
    static let freeTierLanguages: [SupportedLanguage] = [
        .french,
        .english,
        .spanish,
        .german
    ]
}
