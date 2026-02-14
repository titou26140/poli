import SwiftUI

/// The grammar correction tab within the main popover.
struct CorrectionTabView: View {

    @Bindable var appState: AppState

    @State private var correctedText: String?
    @State private var explanation: String?
    @State private var errors: [AIService.CorrectionError] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    // MARK: - Colors

    private let primaryColor = Color(red: 0.357, green: 0.373, blue: 0.902) // #5B5FE6
    private let successColor = Color(red: 0.204, green: 0.780, blue: 0.349) // #34C759
    private let errorColor = Color(red: 1.0, green: 0.231, blue: 0.188)     // #FF3B30

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                inputSection
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
            Text("Texte a corriger")
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
                .frame(minHeight: 100, maxHeight: 140)
        }
    }

    // MARK: - Action Section

    private var actionSection: some View {
        HStack {
            Button {
                Task { await performCorrection() }
            } label: {
                HStack(spacing: 6) {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "textformat.abc")
                    }
                    Text("Corriger")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(primaryColor)
            .controlSize(.large)
            .disabled(appState.inputText.isBlank || isLoading)
        }
    }

    // MARK: - Result Section

    @ViewBuilder
    private var resultSection: some View {
        if let corrected = correctedText {
            VStack(alignment: .leading, spacing: 10) {
                Text("Resultat")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                DiffTextView(original: appState.inputText, corrected: corrected)
                    .frame(minHeight: 60, maxHeight: 120)

                // Detailed errors with rules
                if !errors.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(errors.enumerated()), id: \.offset) { _, error in
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
                                            .foregroundStyle(errorColor)
                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 9))
                                            .foregroundStyle(.secondary)
                                        Text(error.correction)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(successColor)
                                    }

                                    Text(error.rule)
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
                            .fill(primaryColor.opacity(0.04))
                    )
                }

                Button {
                    ClipboardService.shared.write(corrected)
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
                errorMessage = PoliError.dailyLimitReached.localizedDescription
                isLoading = false
                return
            }

            let result = try await GrammarService.shared.correct(text: appState.inputText)
            correctedText = result.corrected
            explanation = result.explanation
            errors = result.errors

            ClipboardService.shared.write(result.corrected)
            UsageTracker.shared.increment()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
