import SwiftUI

/// The translation tab within the main popover.
struct TranslationTabView: View {

    @Bindable var appState: AppState

    @State private var translatedText: String?
    @State private var detectedLanguage: SupportedLanguage?
    @State private var tips: [AIService.TranslationTip] = []
    @State private var targetLanguage: SupportedLanguage = Constants.defaultTargetLanguage
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    // MARK: - Colors

    private let primaryColor = Color(red: 0.357, green: 0.373, blue: 0.902) // #5B5FE6
    private let violetColor = Color(red: 0.608, green: 0.435, blue: 0.910)  // #9B6FE8
    private let errorColor = Color(red: 1.0, green: 0.231, blue: 0.188)     // #FF3B30

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                inputSection
                languageSection
                actionSection
                resultSection
                usageSection
            }
            .padding(16)
        }
    }

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Texte a traduire")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            TextEditor(text: $appState.inputText)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
                .frame(minHeight: 80, maxHeight: 120)
        }
    }

    // MARK: - Language Section

    private var languageSection: some View {
        HStack {
            LanguagePicker(
                selection: $targetLanguage,
                isPaid: EntitlementManager.shared.isPaid
            )
            Spacer()
        }
    }

    // MARK: - Action Section

    private var actionSection: some View {
        Button {
            Task { await performTranslation() }
        } label: {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "globe")
                }
                Text("Traduire")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(violetColor)
        .controlSize(.large)
        .disabled(appState.inputText.isBlank || isLoading)
    }

    // MARK: - Result Section

    @ViewBuilder
    private var resultSection: some View {
        if let translated = translatedText {
            VStack(alignment: .leading, spacing: 10) {
                // Language direction indicator.
                if let source = detectedLanguage {
                    HStack(spacing: 8) {
                        Text(source.flag)
                            .font(.title3)
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(targetLanguage.flag)
                            .font(.title3)

                        Spacer()

                        Text("\(source.displayName) \u{2192} \(targetLanguage.displayName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Text("Traduction")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Text(translated)
                    .font(.body)
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                // Tips section — only shown if there are tips
                if !tips.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(tips.enumerated()), id: \.offset) { _, tip in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.orange)
                                    .padding(.top, 2)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(tip.term)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(violetColor)

                                    Text(tip.tip)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(violetColor.opacity(0.04))
                    )
                }

                Button {
                    ClipboardService.shared.write(translated)
                    PasteService.shared.pasteIfTextFieldActive()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.doc")
                        Text("Copier")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
        }

        if let error = errorMessage {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(errorColor)
                Text(error)
                    .font(.caption)
                    .foregroundStyle(errorColor)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(errorColor.opacity(0.08))
            )
        }
    }

    // MARK: - Usage Section

    private var usageSection: some View {
        UsageMeter(
            used: UsageTracker.shared.todayCount,
            limit: EntitlementManager.shared.dailyLimit,
            tier: EntitlementManager.shared.currentTier
        )
    }

    // MARK: - Translation Logic

    @MainActor
    private func performTranslation() async {
        guard !appState.inputText.isBlank else { return }

        if !EntitlementManager.shared.isLanguageAvailable(targetLanguage) {
            errorMessage = PoliError.notSubscribed.localizedDescription
            return
        }

        isLoading = true
        translatedText = nil
        detectedLanguage = nil
        tips = []
        errorMessage = nil

        do {
            guard EntitlementManager.shared.canPerformAction() else {
                errorMessage = PoliError.dailyLimitReached.localizedDescription
                isLoading = false
                return
            }

            let result = try await TranslationService.shared.translate(
                text: appState.inputText,
                targetLanguage: targetLanguage
            )
            translatedText = result.translated
            detectedLanguage = SupportedLanguage(rawValue: result.sourceLanguage)
            tips = result.tips

            ClipboardService.shared.write(result.translated)
            UsageTracker.shared.increment()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
