import SwiftUI

/// Reusable loading indicator shown inside correction and translation tabs.
struct TabLoadingView: View {
    let message: LocalizedStringKey

    var body: some View {
        VStack(spacing: 10) {
            Image("Mascot")
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
                .opacity(0.6)
            ProgressView()
                .controlSize(.small)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}
