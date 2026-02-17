import SwiftUI

/// Inline error banner displayed below results in correction and translation tabs.
struct InlineErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.poliError)
            Text(message)
                .font(.caption)
                .foregroundStyle(Color.poliError)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.poliError.opacity(0.08))
        )
    }
}
