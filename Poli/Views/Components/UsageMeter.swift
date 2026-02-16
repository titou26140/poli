import SwiftUI

/// A compact gauge showing remaining actions.
///
/// Displays a progress bar with a color gradient that transitions from green
/// (plenty of actions left) through orange to red (almost exhausted).
struct UsageMeter: View {

    /// Number of actions used.
    let used: Int

    /// Maximum number of actions allowed for the current tier.
    let limit: Int

    /// The user's current subscription tier.
    let tier: SubscriptionTier

    // MARK: - Computed

    private var remaining: Int {
        max(limit - used, 0)
    }

    private var progress: Double {
        guard limit > 0 else { return 0 }
        return Double(used) / Double(limit)
    }

    private var barColor: Color {
        switch progress {
        case ..<0.5:
            return Color(red: 0.204, green: 0.780, blue: 0.349) // #34C759
        case 0.5..<0.8:
            return Color(red: 0.961, green: 0.651, blue: 0.137) // #F5A623
        default:
            return Color(red: 1.0, green: 0.231, blue: 0.188)   // #FF3B30
        }
    }

    private var remainingLabel: String {
        if tier.isLifetimeLimit {
            return String(format: String(localized: "usage.remaining"), remaining, limit)
        } else {
            return String(format: String(localized: "usage.remaining_today"), remaining, limit)
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(remainingLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if tier.isPaid {
                    Text(tier.displayName)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color(red: 0.357, green: 0.373, blue: 0.902))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.357, green: 0.373, blue: 0.902).opacity(0.1))
                        )
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(nsColor: .separatorColor))
                        .frame(height: 6)

                    Capsule()
                        .fill(barColor)
                        .frame(
                            width: max(geometry.size.width * (1.0 - progress), 0),
                            height: 6
                        )
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Preview

#Preview("Free tier") {
    UsageMeter(used: 2, limit: 10, tier: .free)
        .padding()
        .frame(width: 300)
}

#Preview("Starter tier") {
    UsageMeter(used: 15, limit: 50, tier: .starter)
        .padding()
        .frame(width: 300)
}

#Preview("Pro tier") {
    UsageMeter(used: 42, limit: 500, tier: .pro)
        .padding()
        .frame(width: 300)
}
