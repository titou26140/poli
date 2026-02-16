import Foundation
import Combine

/// Centralizes subscription entitlement checks for the entire application.
///
/// Other services (e.g. `UsageTracker`, `HistoryManager`) query `currentTier`
/// to determine whether to enforce free-tier restrictions.
@MainActor
final class EntitlementManager: ObservableObject {

    // MARK: - Singleton

    static let shared = EntitlementManager()

    // MARK: - Published State

    /// The user's current subscription tier.
    @Published var currentTier: SubscriptionTier = .free {
        didSet {
            // Persist tier to UserDefaults so it's available immediately on next launch.
            UserDefaults.standard.set(currentTier.rawValue, forKey: Constants.UserDefaultsKey.cachedSubscriptionTier)
            print("[EntitlementManager] currentTier changed: \(currentTier.rawValue)")
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

    /// Whether the backend has confirmed the subscription status.
    @Published var isBackendSynced: Bool = false

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    private init() {
        // Restore cached tier from UserDefaults so the UI shows the correct
        // state immediately, before the async StoreKit check completes.
        if let cached = UserDefaults.standard.string(forKey: Constants.UserDefaultsKey.cachedSubscriptionTier),
           let tier = SubscriptionTier(rawValue: cached) {
            self.currentTier = tier
            // Use the cached remaining actions from UsageTracker (backend-synced),
            // NOT tier.usageLimit which would ignore actual usage.
            self.remainingActions = UsageTracker.shared.remainingActions
            print("[EntitlementManager] Restored cached tier: \(tier.rawValue), remaining: \(self.remainingActions)")
        }

        // Observe the StoreManager's purchased product IDs and derive tier.
        // Use .dropFirst() to skip the initial empty value — we rely on the
        // cached tier until updatePurchasedProducts() actually completes.
        StoreManager.shared.$purchasedProductIDs
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] productIDs in
                guard let self else { return }
                print("[EntitlementManager] Received purchasedProductIDs update: \(productIDs)")
                if !productIDs.isEmpty {
                    let tier = self.bestTier(from: productIDs)
                    self.currentTier = tier
                } else if !self.isBackendSynced {
                    // StoreKit confirmed no active entitlements — trust it
                    // and clear any stale cached tier.
                    self.currentTier = .free
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Entitlement Checks

    /// Re-evaluates entitlements from the current StoreManager state.
    func checkEntitlements() {
        let productIDs = StoreManager.shared.purchasedProductIDs
        if !productIDs.isEmpty {
            currentTier = bestTier(from: productIDs)
        } else if !isBackendSynced {
            currentTier = .free
        }
    }

    /// Whether the user can perform another action today.
    func canPerformAction() -> Bool {
        return UsageTracker.shared.canPerformAction
    }

    /// Updates entitlement state from backend user data.
    func updateFromBackend(tier: SubscriptionTier, remainingActions: Int) {
        self.currentTier = tier
        self.remainingActions = remainingActions
        UsageTracker.shared.syncFromBackend(remainingActions: remainingActions)
        if tier.isPaid {
            self.isBackendSynced = true
        }
    }

    /// Whether the given language is available to the user.
    ///
    /// Paid users have access to all languages. Free users are limited to
    /// `SupportedLanguage.freeTierLanguages`.
    func isLanguageAvailable(_ language: SupportedLanguage) -> Bool {
        if isPaid { return true }
        return SupportedLanguage.freeTierLanguages.contains(language)
    }

    // MARK: - Private Helpers

    /// Returns the highest tier from a set of purchased product IDs.
    private func bestTier(from productIDs: Set<String>) -> SubscriptionTier {
        if productIDs.contains(StoreManager.ProductID.proMonthly) {
            return .pro
        } else if productIDs.contains(StoreManager.ProductID.starterMonthly) {
            return .starter
        }
        return .free
    }
}
