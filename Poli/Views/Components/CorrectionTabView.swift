import SwiftUI

/// The grammar correction tab within the main popover.
struct CorrectionTabView: View {

    @Bindable var appState: AppState

    @State private var correctedText: String?
    @State private var explanation: String?
    @State private var errors: [AIService.CorrectionError] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var correctionTask: Task<Void, Never>?

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                inputSection
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
            correctedText = nil
            explanation = nil
            errors = []
            errorMessage = nil
        }
        .onDisappear {
            correctionTask?.cancel()
        }
    }

    // MARK: - Input Section

    private var inputSection: some View {
        PoliTextEditor(label: "correction.input_label", text: $appState.inputText, maxHeight: 140)
    }

    // MARK: - Action Section

    private var actionSection: some View {
        HStack {
            Button {
                correctionTask?.cancel()
                correctionTask = Task { await performCorrection() }
            } label: {
                HStack(spacing: 6) {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "textformat.abc")
                    }
                    Text("correction.button")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.poliPrimary)
            .controlSize(.large)
            .disabled(appState.inputText.isBlank || isLoading)
        }
    }

    // MARK: - Loading Section

    private var loadingSection: some View {
        TabLoadingView(message: "correction.loading")
    }

    // MARK: - Result Section

    @ViewBuilder
    private var resultSection: some View {
        if let corrected = correctedText {
            VStack(alignment: .leading, spacing: 10) {
                Text("correction.result_label")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                DiffTextView(original: appState.inputText, corrected: corrected)
                    .frame(minHeight: 60, maxHeight: 120)

                // Detailed errors with rules
                if !errors.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(errors) { error in
                            CorrectionErrorRow(error: error)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.poliPrimary.opacity(0.04))
                    )
                }

                Button {
                    ClipboardService.shared.write(corrected)
                    PasteService.shared.pasteIfTextFieldActive()
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

    // MARK: - Correction Logic

    @MainActor
    private func performCorrection() async {
        guard !appState.inputText.isBlank else { return }

        isLoading = true
        correctedText = nil
        explanation = nil
        errors = []
        errorMessage = nil

        do {
            guard EntitlementManager.shared.canPerformAction() else {
                errorMessage = PoliError.usageLimitReached.localizedDescription
                isLoading = false
                return
            }

            let result = try await GrammarService.shared.correct(text: appState.inputText)
            correctedText = result.corrected
            explanation = result.explanation
            errors = result.errors

            ClipboardService.shared.write(result.corrected)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
