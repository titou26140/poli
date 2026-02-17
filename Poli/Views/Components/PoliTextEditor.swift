import SwiftUI

/// A styled TextEditor with consistent appearance across the app.
struct PoliTextEditor: View {
    let label: LocalizedStringKey
    @Binding var text: String
    var maxHeight: CGFloat = 140

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            TextEditor(text: $text)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
                .frame(minHeight: 80, maxHeight: maxHeight)
        }
    }
}
