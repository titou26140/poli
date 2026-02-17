import Foundation

enum Constants {

    // MARK: - Usage Limits

    /// Maximum number of actions for free-tier users (lifetime, not per day).
    static let lifetimeFreeLimit = 10

    /// Maximum number of actions per day for Starter-tier users.
    static let dailyStarterLimit = 50

    /// Maximum number of actions per day for Pro-tier users.
    static let dailyProLimit = 500

    /// Maximum text length (in characters) for free-tier users.
    static let maxTextLengthFree = 5_000

    /// Maximum text length (in characters) for paid-tier users.
    static let maxTextLengthPaid = 20_000

    // MARK: - Defaults

    /// The default target language used for translations.
    static let defaultTargetLanguage: SupportedLanguage = .english

    // MARK: - Keychain

    /// The keychain service identifier used to store credentials.
    static let keychainServiceName = "com.poli"

    /// The Keychain key for the authentication token.
    static let keychainAuthTokenKey = "auth_token"

    // MARK: - Networking

    /// Base URL for the Poli backend API.
    /// Determined by build configuration: Debug → local, Staging → staging, Release → production.
    static let apiBaseURL: URL = {
        #if DEBUG
        return URL(string: "https://poli.test")!
        #elseif STAGING
        return URL(string: "https://staging.poli-app.com")!
        #else
        return URL(string: "https://poli-app.com")!
        #endif
    }()

    // MARK: - Bundle

    /// The application bundle identifier.
    static let bundleIdentifier = "com.poli-app.poli"

    // MARK: - UserDefaults Keys

    enum UserDefaultsKey {
        static let targetLanguage = "targetLanguage"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let lastUsageResetDate = "lastUsageResetDate"
        static let dailyUsageCount = "dailyUsageCount"
        static let lifetimeUsageCount = "lifetimeUsageCount"
        static let unsyncedTransactionIDs = "unsyncedTransactionIDs"
        static let cachedSubscriptionTier = "cachedSubscriptionTier"
        static let cachedSubscriptionStatus = "cachedSubscriptionStatus"
        static let cachedRemainingActions = "cachedRemainingActions"
        static let userLanguage = "userLanguage"
        static let correctionShortcutKeyCode = "correctionShortcutKeyCode"
        static let correctionShortcutModifiers = "correctionShortcutModifiers"
        static let translationShortcutKeyCode = "translationShortcutKeyCode"
        static let translationShortcutModifiers = "translationShortcutModifiers"
        static let appLanguage = "appLanguage"
    }
}
