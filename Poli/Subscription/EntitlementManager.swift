import Combine
import Foundation

/// Centralizes subscription entitlement checks for the entire application.
///
/// The **backend is the single source of truth** for tier and usage.
/// StoreKit is only used to detect transactions and forward them to the
/// backend via `/verify`. This class simply reflects whatever the backend
/// reports, with a UserDefaults cache for instant display on launch.
@MainActor
final class EntitlementManager: ObservableObject {

    // MARK: - Singleton

    static let shared = EntitlementManager()

    // MARK: - Published State

    /// The user's current subscription tier.
    @Published var currentTier: SubscriptionTier = .free {
        didSet {
            UserDefaults.standard.set(currentTier.rawValue, forKey: Constants.UserDefaultsKey.cachedSubscriptionTier)
            #if DEBUG
            print("[EntitlementManager] currentTier changed: \(currentTier.rawValue)")
            #endif
        }
    }

    /// Convenience: whether the user has any paid plan.
    var isPaid: Bool { currentTier.isPaid }

    /// Legacy convenience kept for call sites that check Pro specifically.
    var isPro: Bool { currentTier == .pro }

    /// The usage limit for the current tier.
    var usageLimit: Int { currentTier.usageLimit }

    /// Remaining actions (synced from backend via UsageTracker).
    @Published var remainingActions: Int = 0

    /// The subscription lifecycle status from the backend.
    @Published var subscriptionStatus: SubscriptionStatus = .none {
        didSet {
            UserDefaults.standard.set(subscriptionStatus.rawValue, forKey: Constants.UserDefaultsKey.cachedSubscriptionStatus)
            #if DEBUG
            print("[EntitlementManager] subscriptionStatus changed: \(subscriptionStatus.rawValue)")
            #endif
        }
    }

    /// When the current subscription period expires.
    @Published var expiresAt: Date?

    /// When the user cancelled their subscription (nil if not cancelled).
    @Published var cancelledAt: Date?

    // MARK: - Init

    private init() {
        // Restore cached state from UserDefaults for instant UI display on launch.
        // The backend will overwrite these values once fetchCurrentUser() completes.
        if let cached = UserDefaults.standard.string(forKey: Constants.UserDefaultsKey.cachedSubscriptionTier),
           let tier = SubscriptionTier(rawValue: cached) {
            self.currentTier = tier
            self.remainingActions = UsageTracker.shared.remainingActions
            #if DEBUG
            print("[EntitlementManager] Restored cached tier: \(tier.rawValue), remaining: \(self.remainingActions)")
            #endif
        }

        if let cachedStatus = UserDefaults.standard.string(forKey: Constants.UserDefaultsKey.cachedSubscriptionStatus),
           let status = SubscriptionStatus(rawValue: cachedStatus) {
            self.subscriptionStatus = status
            #if DEBUG
            print("[EntitlementManager] Restored cached status: \(status.rawValue)")
            #endif
        }
    }

    // MARK: - Entitlement Checks

    /// Whether the user can perform another action today.
    func canPerformAction() -> Bool {
        return UsageTracker.shared.canPerformAction
    }

    /// Resets all entitlement state on logout.
    func reset() {
        currentTier = .free
        remainingActions = 0
        subscriptionStatus = .none
        expiresAt = nil
        cancelledAt = nil
        UsageTracker.shared.syncFromBackend(remainingActions: 0)
    }

    /// Updates entitlement state from backend data.
    func updateFromBackend(
        tier: SubscriptionTier,
        remainingActions: Int,
        status: SubscriptionStatus = .none,
        expiresAt: Date? = nil,
        cancelledAt: Date? = nil
    ) {
        self.currentTier = tier
        self.remainingActions = remainingActions
        self.subscriptionStatus = tier.isPaid ? status : .none
        self.expiresAt = expiresAt
        self.cancelledAt = cancelledAt
        UsageTracker.shared.syncFromBackend(remainingActions: remainingActions)
    }

    /// Whether the given language is available to the user.
    ///
    /// Paid users have access to all languages. Free users are limited to
    /// `SupportedLanguage.freeTierLanguages`.
    func isLanguageAvailable(_ language: SupportedLanguage) -> Bool {
        if isPaid { return true }
        return SupportedLanguage.freeTierLanguages.contains(language)
    }

    // MARK: - Status Helpers

    /// Whether the subscription is in Apple's billing grace period.
    var isInGracePeriod: Bool {
        subscriptionStatus == .gracePeriod
    }

    /// Whether the user cancelled but still has access until the period ends.
    var isCancelledButActive: Bool {
        subscriptionStatus == .cancelled && currentTier.isPaid
    }

    /// Formatted expiration date for display, or nil if unavailable.
    private static let expiresDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }()

    var expiresAtFormatted: String? {
        guard let expiresAt else { return nil }
        return Self.expiresDateFormatter.string(from: expiresAt)
    }

}
