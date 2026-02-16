import AppKit
import SwiftUI

/// A floating toast displayed at the top of the screen showing the result of a
/// correction or translation, along with learning tips when available.
/// Does not steal focus from the active app.
final class ResultBanner {

    private static var panel: NSPanel?
    private static var autoDismissWork: DispatchWorkItem?
    private static var dismissDuration: TimeInterval = 4
    private static var isHovered: Bool = false

    // MARK: - Public API

    @MainActor
    static func show(
        title: String,
        resultText: String,
        correctionErrors: [AIService.CorrectionError] = [],
        translationTips: [AIService.TranslationTip] = [],
        duration: TimeInterval? = nil
    ) {
        dismiss()

        let hasLearning = !correctionErrors.isEmpty || !translationTips.isEmpty
        let tipCount = correctionErrors.count + translationTips.count

        // Longer duration when there are tips to read.
        let effectiveDuration = duration ?? (hasLearning ? min(6 + Double(tipCount) * 2.5, 20) : 4)

        let panelWidth: CGFloat = hasLearning ? 400 : 380

        let contentView = BannerContentView(
            title: title,
            resultText: resultText,
            correctionErrors: correctionErrors,
            translationTips: translationTips,
            onClose: { Self.dismiss() }
        )

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.setFrameSize(NSSize(
            width: panelWidth,
            height: hostingView.fittingSize.height
        ))

        let panelHeight = hostingView.fittingSize.height

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.contentView = hostingView

        // Position at top center
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - panelWidth / 2
            let y = screenFrame.maxY - panelHeight - 12
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        self.panel = panel

        // Fade in
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            panel.animator().alphaValue = 1
        }

        // Auto-dismiss
        dismissDuration = effectiveDuration
        isHovered = false
        scheduleAutoDismiss(delay: effectiveDuration)
    }

    /// Pauses auto-dismiss while the user hovers the banner.
    @MainActor
    static func setHovered(_ hovered: Bool) {
        isHovered = hovered
        if hovered {
            autoDismissWork?.cancel()
            autoDismissWork = nil
        } else {
            // Short delay after mouse leaves to let the user re-enter.
            scheduleAutoDismiss(delay: 2)
        }
    }

    @MainActor
    private static func scheduleAutoDismiss(delay: TimeInterval) {
        autoDismissWork?.cancel()
        let work = DispatchWorkItem {
            Task { @MainActor in Self.dismiss() }
        }
        autoDismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    @MainActor
    static func dismiss() {
        autoDismissWork?.cancel()
        autoDismissWork = nil
        guard let panel else { return }
        self.panel = nil
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.close()
        })
    }
}

// MARK: - SwiftUI Content

private struct BannerContentView: View {
    let title: String
    let resultText: String
    let correctionErrors: [AIService.CorrectionError]
    let translationTips: [AIService.TranslationTip]
    let onClose: () -> Void

    private let primaryColor = Color(red: 0.357, green: 0.373, blue: 0.902)
    private let successColor = Color(red: 0.204, green: 0.780, blue: 0.349)
    private let violetColor = Color(red: 0.608, green: 0.435, blue: 0.910)

    private var hasLearning: Bool {
        !correctionErrors.isEmpty || !translationTips.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Result section
            resultHeader
                .padding(14)

            // Learning section
            if hasLearning {
                Divider()
                    .padding(.horizontal, 14)

                learningSection
                    .padding(14)
            }
        }
        .frame(width: hasLearning ? 400 : 380)
        .fixedSize(horizontal: false, vertical: true)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
        )
        .onHover { hovering in
            ResultBanner.setHovered(hovering)
        }
    }

    // MARK: - Result Header

    private var resultHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(successColor)
                    .font(.system(size: 15))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .frame(width: 20, height: 20)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .focusable(false)
            }

            Text(resultText)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("banner.copied")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Learning Section

    private var learningSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("\u{1F4A1}")
                    .font(.system(size: 13))
                Text(correctionErrors.isEmpty
                     ? String(localized: "detail.tips_label")
                     : String(localized: "detail.corrections_label"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(primaryColor)
            }

            if !correctionErrors.isEmpty {
                correctionErrorsList
            }

            if !translationTips.isEmpty {
                translationTipsList
            }
        }
    }

    // MARK: - Correction Errors

    private var correctionErrorsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(correctionErrors.prefix(3).enumerated()), id: \.offset) { _, error in
                HStack(alignment: .top, spacing: 8) {
                    Text("\u{270F}\u{FE0F}")
                        .font(.system(size: 11))

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Text(error.original)
                                .font(.system(size: 11, weight: .medium))
                                .strikethrough()
                                .foregroundStyle(.red.opacity(0.8))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.secondary)
                            Text(error.correction)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(successColor)
                        }

                        Text(error.rule)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(primaryColor.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Translation Tips

    private var translationTipsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(translationTips.prefix(3).enumerated()), id: \.offset) { _, tip in
                HStack(alignment: .top, spacing: 8) {
                    Text("\u{1F30D}")
                        .font(.system(size: 11))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(tip.term)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(violetColor)

                        Text(tip.tip)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(violetColor.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}
