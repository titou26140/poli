import SwiftUI

/// The translation tab within the main popover.
struct TranslationTabView: View {

    @Bindable var appState: AppState

    @State private var translatedText: String?
    @State private var detectedLanguage: SupportedLanguage?
    @State private var tips: [AIService.TranslationTip] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var translationTask: Task<Void, Never>?

    @AppStorage(Constants.UserDefaultsKey.targetLanguage)
    private var targetLanguageCode: String = Constants.defaultTargetLanguage.rawValue

    private var targetLanguage: SupportedLanguage {
        SupportedLanguage(rawValue: targetLanguageCode) ?? .english
    }

    private var targetLanguageBinding: Binding<SupportedLanguage> {
        Binding(
            get: { SupportedLanguage(rawValue: targetLanguageCode) ?? .english },
            set: { targetLanguageCode = $0.rawValue }
        )
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                inputSection
                languageSection
                actionSection
                if isLoading {
                    loadingSection
                }
                resultSection
                if !EntitlementManager.shared.isPaid {
                    usageSection
                }
            }
            .padding(16)
        }
        .onChange(of: appState.inputText) {
            translatedText = nil
            detectedLanguage = nil
            tips = []
            errorMessage = nil
        }
        .onDisappear {
            translationTask?.cancel()
        }
    }

    // MARK: - Input Section

    private var inputSection: some View {
        PoliTextEditor(label: "translation.input_label", text: $appState.inputText, maxHeight: 120)
    }

    // MARK: - Language Section

    private var languageSection: some View {
        HStack {
            LanguagePicker(
                selection: targetLanguageBinding,
                isPaid: EntitlementManager.shared.isPaid
            )
            Spacer()
        }
    }

    // MARK: - Action Section

    private var actionSection: some View {
        Button {
            translationTask?.cancel()
            translationTask = Task { await performTranslation() }
        } label: {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "globe")
                }
                Text("translation.button")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.poliSecondary)
        .controlSize(.large)
        .disabled(appState.inputText.isBlank || isLoading)
    }

    // MARK: - Loading Section

    private var loadingSection: some View {
        TabLoadingView(message: "translation.loading")
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

                Text("translation.result_label")
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
                        ForEach(tips) { tip in
                            TranslationTipRow(tip: tip)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.poliSecondary.opacity(0.04))
                    )
                }

                Button {
                    ClipboardService.shared.write(translated)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.doc")
                        Text("common.copy")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
        }

        if let error = errorMessage {
            InlineErrorBanner(message: error)
        }
    }

    // MARK: - Usage Section

    private var usageSection: some View {
        UsageMeter(
            used: UsageTracker.shared.usedCount,
            limit: UsageTracker.shared.limit,
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
                errorMessage = PoliError.usageLimitReached.localizedDescription
                isLoading = false
                NotificationCenter.default.post(name: .openPaywall, object: nil)
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
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
