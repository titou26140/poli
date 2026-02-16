import Foundation

/// Tracks and enforces usage limits, synced from the backend.
///
/// The **backend is the single source of truth** for remaining actions.
/// Local state is only a cache for UI display between API calls.
/// The app never increments counters locally — it trusts the
/// `remaining_actions` value returned by the backend after each request.
@MainActor
@Observable
final class UsageTracker {

    // MARK: - Singleton

    static let shared = UsageTracker()

    // MARK: - Private

    private let defaults = UserDefaults.standard

    /// Whether the backend has synced at least once this session.
    private(set) var hasSynced: Bool = false

    private init() {
        // Restore cached remaining actions for immediate UI display on launch.
        // If the key doesn't exist, integer(forKey:) returns 0 — which is safe
        // because the first backend response will set the correct value.
        _remainingActions = defaults.integer(forKey: Constants.UserDefaultsKey.cachedRemainingActions)
    }

    // MARK: - State

    /// Remaining actions as last reported by the backend.
    private var _remainingActions: Int = 0

    /// The current tier from EntitlementManager.
    private var tier: SubscriptionTier {
        EntitlementManager.shared.currentTier
    }

    /// The usage limit for the current tier.
    var limit: Int {
        tier.usageLimit
    }

    /// The number of actions used (derived from backend remaining).
    var usedCount: Int {
        max(0, limit - _remainingActions)
    }

    /// The number of remaining actions available (from backend).
    var remainingActions: Int {
        _remainingActions
    }

    /// Whether the user is allowed to perform another action.
    var canPerformAction: Bool {
        _remainingActions > 0
    }

    // MARK: - Backend Sync

    /// Updates remaining actions from a backend response.
    ///
    /// Called automatically by `AIService` after each successful
    /// correction/translation, and by `AuthManager` on login/fetch.
    func syncFromBackend(remainingActions: Int) {
        _remainingActions = remainingActions
        hasSynced = true
        defaults.set(remainingActions, forKey: Constants.UserDefaultsKey.cachedRemainingActions)
    }
}
