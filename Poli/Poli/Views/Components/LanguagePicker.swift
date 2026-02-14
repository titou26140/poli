import SwiftUI

/// A compact language selector that displays a flag and language name for each option.
///
/// Respects free-tier limitations by showing a lock icon next to languages
/// that are only available with a paid subscription.
struct LanguagePicker: View {

    @Binding var selection: SupportedLanguage
    var isPaid: Bool = false

    var body: some View {
        Picker(selection: $selection) {
            ForEach(SupportedLanguage.allCases, id: \.self) { language in
                HStack(spacing: 6) {
                    Text(language.flag)
                    Text(language.displayName)
                        .lineLimit(1)

                    if !isPaid && !SupportedLanguage.freeTierLanguages.contains(language) {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .tag(language)
            }
        } label: {
            Label {
                Text("Langue cible")
            } icon: {
                Image(systemName: "globe")
            }
        }
        .pickerStyle(.menu)
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var language: SupportedLanguage = .english
        var body: some View {
            VStack(spacing: 16) {
                LanguagePicker(selection: $language, isPaid: false)
                LanguagePicker(selection: $language, isPaid: true)
            }
            .padding()
            .frame(width: 300)
        }
    }
    return PreviewWrapper()
}
