import SwiftUI

/// A single translation tip row showing term + explanation.
struct TranslationTipRow: View {
    let tip: AIService.TranslationTip

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 11))
                .foregroundStyle(.orange)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(tip.term)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.poliSecondary)

                Text(tip.tip)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
