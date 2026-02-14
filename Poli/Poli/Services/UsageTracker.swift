import Foundation

/// Tracks and enforces daily usage limits.
///
/// The counter resets at the start of each calendar day (00:00).
/// The daily limit depends on the user's current subscription tier.
@MainActor
final class UsageTracker {

    // MARK: - Singleton

    static let shared = UsageTracker()

    // MARK: - Private

    private let defaults = UserDefaults.standard

    private init() {
        resetIfNewDay()
    }

    // MARK: - Public API

    /// The daily limit for the current subscription tier.
    var dailyLimit: Int {
        EntitlementManager.shared.currentTier.dailyLimit
    }

    /// The number of actions performed today. Automatically resets on a new day.
    var todayCount: Int {
        resetIfNewDay()
        return defaults.integer(forKey: Constants.UserDefaultsKey.dailyUsageCount)
    }

    /// Whether the user is allowed to perform another action.
    var canPerformAction: Bool {
        return todayCount < dailyLimit
    }

    /// The number of remaining actions available today.
    var remainingActions: Int {
        return max(0, dailyLimit - todayCount)
    }

    /// Increments the daily usage counter by one.
    func increment() {
        resetIfNewDay()
        let current = defaults.integer(forKey: Constants.UserDefaultsKey.dailyUsageCount)
        defaults.set(current + 1, forKey: Constants.UserDefaultsKey.dailyUsageCount)
    }

    /// Resets the counter if the stored date does not match today.
    func resetIfNewDay() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let storedDate = defaults.object(forKey: Constants.UserDefaultsKey.lastUsageResetDate) as? Date {
            if !calendar.isDate(storedDate, inSameDayAs: today) {
                defaults.set(0, forKey: Constants.UserDefaultsKey.dailyUsageCount)
                defaults.set(today, forKey: Constants.UserDefaultsKey.lastUsageResetDate)
            }
        } else {
            defaults.set(0, forKey: Constants.UserDefaultsKey.dailyUsageCount)
            defaults.set(today, forKey: Constants.UserDefaultsKey.lastUsageResetDate)
        }
    }
}
