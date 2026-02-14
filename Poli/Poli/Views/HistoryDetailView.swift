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
                        title: "Texte original",
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
        .alert("Supprimer cette entree ?", isPresented: $showDeleteConfirmation) {
            Button("Annuler", role: .cancel) {}
            Button("Supprimer", role: .destructive) {
                onDelete()
                dismiss()
            }
        } message: {
            Text("Cette action est irreversible.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: entry.iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(entry.isCorrection ? .green : .blue)

            Text(entry.isCorrection ? "Correction" : "Traduction")
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
                Label("Texte corrige", systemImage: "checkmark.circle")
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
                    Label("Traduction", systemImage: "globe")
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
        let originalWords = original.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        let correctedWords = corrected.split(separator: " ", omittingEmptySubsequences: false).map(String.init)

        return VStack(alignment: .leading, spacing: 4) {
            let attributedText = buildDiffAttributedText(original: originalWords, corrected: correctedWords)
            Text(attributedText)
                .font(.system(size: 13))
                .textSelection(.enabled)
        }
    }

    private func buildDiffAttributedText(original: [String], corrected: [String]) -> AttributedString {
        var result = AttributedString()

        for (index, word) in corrected.enumerated() {
            if index > 0 {
                result.append(AttributedString(" "))
            }

            var attrWord = AttributedString(word)
            if index >= original.count || (index < original.count && original[index] != word) {
                attrWord.foregroundColor = .green
                attrWord.font = .system(size: 13, weight: .semibold)
            }

            result.append(attrWord)
        }

        return result
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

    private let primaryColor = Color(red: 0.357, green: 0.373, blue: 0.902) // #5B5FE6
    private let successColor = Color(red: 0.204, green: 0.780, blue: 0.349) // #34C759
    private let errorColor = Color(red: 1.0, green: 0.231, blue: 0.188)     // #FF3B30

    private func correctionErrorsSection(_ errors: [AIService.CorrectionError]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Corrections", systemImage: "lightbulb")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.orange)

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
    }

    // MARK: - Translation Tips Section

    private let violetColor = Color(red: 0.608, green: 0.435, blue: 0.910) // #9B6FE8

    private func translationTipsSection(_ tips: [AIService.TranslationTip]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Tips", systemImage: "lightbulb")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.orange)

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
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button {
                ClipboardService.shared.write(entry.resultText)
            } label: {
                Label("Copier", systemImage: "doc.on.doc")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.bordered)

            Button {
                onFavoriteToggle()
            } label: {
                Label(
                    entry.isFavorite ? "Favori" : "Ajouter aux favoris",
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
                Label("Supprimer", systemImage: "trash")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
