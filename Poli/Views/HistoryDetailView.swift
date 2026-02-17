import SwiftUI

struct HistoryDetailView: View {

    let entry: HistoryEntry
    let onFavoriteToggle: () -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation: Bool = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    metadataBar
                    textSection(
                        title: String(localized: "detail.original_text"),
                        text: entry.originalText,
                        icon: "text.quote"
                    )
                    resultSection

                    if entry.isCorrection, let errors = entry.errors, !errors.isEmpty {
                        correctionErrorsSection(errors)
                    }

                    if entry.isTranslation, let tips = entry.tips, !tips.isEmpty {
                        translationTipsSection(tips)
                    }
                }
                .padding(20)
            }

            Divider()
            actionBar
        }
        .frame(width: 480, height: 400)
        .alert(String(localized: "detail.delete_confirm.title"), isPresented: $showDeleteConfirmation) {
            Button(String(localized: "detail.delete_confirm.cancel"), role: .cancel) {}
            Button(String(localized: "detail.delete"), role: .destructive) {
                onDelete()
                dismiss()
            }
        } message: {
            Text("detail.delete_confirm.message")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: entry.iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(entry.isCorrection ? .green : .blue)

            Text(entry.isCorrection
                 ? String(localized: "detail.correction")
                 : String(localized: "detail.translation"))
                .font(.system(size: 14, weight: .semibold))

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .focusable(false)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
    }

    // MARK: - Metadata Bar

    private var metadataBar: some View {
        HStack(spacing: 12) {
            Label {
                Text(entry.createdAt, format: .dateTime.day().month(.wide).year().hour().minute())
                    .font(.system(size: 12))
            } icon: {
                Image(systemName: "calendar")
                    .font(.system(size: 11))
            }
            .foregroundStyle(.secondary)

            Spacer()

            Text(entry.languageInfo)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Text Sections

    private func textSection(title: String, text: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(text)
                .font(.system(size: 13))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        if entry.isCorrection {
            VStack(alignment: .leading, spacing: 8) {
                Label(String(localized: "detail.corrected_text"), systemImage: "checkmark.circle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                diffView(original: entry.originalText, corrected: entry.resultText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.green.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Label(String(localized: "detail.translation"), systemImage: "globe")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    if let src = entry.sourceLanguage {
                        languageBadge(src)
                    }
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                    if let tgt = entry.targetLanguage {
                        languageBadge(tgt)
                    }
                }

                Text(entry.resultText)
                    .font(.system(size: 13))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.blue.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Diff View

    private func diffView(original: String, corrected: String) -> some View {
        DiffTextView(original: original, corrected: corrected)
    }

    // MARK: - Language Badge

    private func languageBadge(_ code: String) -> some View {
        let lang = SupportedLanguage(rawValue: code)
        return HStack(spacing: 3) {
            Text(lang?.flag ?? "")
                .font(.system(size: 12))
            Text(lang?.displayName ?? code)
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.primary.opacity(0.06))
        .clipShape(Capsule())
    }

    // MARK: - Correction Errors Section

    private func correctionErrorsSection(_ errors: [AIService.CorrectionError]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(String(localized: "detail.corrections_label"), systemImage: "lightbulb")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.orange)

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
    }

    // MARK: - Translation Tips Section

    private func translationTipsSection(_ tips: [AIService.TranslationTip]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(String(localized: "detail.tips_label"), systemImage: "lightbulb")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.orange)

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
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button {
                ClipboardService.shared.write(entry.resultText)
            } label: {
                Label(String(localized: "detail.copy"), systemImage: "doc.on.doc")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.bordered)

            Button {
                onFavoriteToggle()
            } label: {
                Label(
                    entry.isFavorite
                        ? String(localized: "detail.favorite")
                        : String(localized: "detail.add_favorite"),
                    systemImage: entry.isFavorite ? "star.fill" : "star"
                )
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(entry.isFavorite ? .yellow : .secondary)
            }
            .buttonStyle(.bordered)

            Spacer()

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label(String(localized: "detail.delete"), systemImage: "trash")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
