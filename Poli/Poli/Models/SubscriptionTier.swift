import Foundation

/// Represents the user's subscription tier.
enum SubscriptionTier: String, Codable, CaseIterable {
    case free
    case starter
    case pro

    /// Maximum number of actions allowed per day.
    var dailyLimit: Int {
        switch self {
        case .free:    return Constants.dailyFreeLimit
        case .starter: return Constants.dailyStarterLimit
        case .pro:     return Constants.dailyProLimit
        }
    }

    /// User-facing display name.
    var displayName: String {
        switch self {
        case .free:    return "Gratuit"
        case .starter: return "Poli Starter"
        case .pro:     return "Poli Pro"
        }
    }

    /// Whether the user has a paid subscription (Starter or Pro).
    var isPaid: Bool {
        self != .free
    }

    /// Maximum text length allowed.
    var maxTextLength: Int {
        switch self {
        case .free: return Constants.maxTextLengthFree
        case .starter, .pro: return Constants.maxTextLengthPaid
        }
    }

    /// Derives a tier from a StoreKit product ID.
    static func from(productID: String) -> SubscriptionTier {
        if productID.contains("pro") {
            return .pro
        } else if productID.contains("starter") {
            return .starter
        }
        return .free
    }

    /// Derives a tier from a backend plan string (e.g. "starter_monthly", "pro_monthly").
    static func from(backendPlan: String) -> SubscriptionTier {
        if backendPlan.contains("pro") {
            return .pro
        } else if backendPlan.contains("starter") {
            return .starter
        }
        return .free
    }
}
