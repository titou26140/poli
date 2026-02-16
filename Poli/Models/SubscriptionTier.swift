import Foundation

/// Represents the user's subscription tier.
enum SubscriptionTier: String, Codable, CaseIterable {
    case free
    case starter
    case pro

    /// Whether the limit is lifetime (free) or daily (paid).
    var isLifetimeLimit: Bool {
        self == .free
    }

    /// The usage limit: lifetime total for free, daily for paid tiers.
    var usageLimit: Int {
        switch self {
        case .free:    return Constants.lifetimeFreeLimit
        case .starter: return Constants.dailyStarterLimit
        case .pro:     return Constants.dailyProLimit
        }
    }

    /// User-facing display name.
    var displayName: String {
        switch self {
        case .free:    return String(localized: "tier.free")
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
