import SwiftUI

/// A single correction error row showing original (strikethrough) → correction + rule.
struct CorrectionErrorRow: View {
    let error: AIService.CorrectionError

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 11))
                .foregroundStyle(.orange)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(error.original)
                        .font(.system(size: 12, weight: .medium))
                        .strikethrough()
                        .foregroundStyle(Color.poliError)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    Text(error.correction)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.poliSuccess)
                }

                Text(error.rule)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
