import AppKit
import SwiftUI

/// A floating toast displayed at the top of the screen showing the result of a
/// correction or translation. Auto-dismisses after a few seconds.
/// Does not steal focus from the active app.
final class ResultBanner {

    private static var panel: NSPanel?
    private static var autoDismissWork: DispatchWorkItem?

    // MARK: - Public API

    /// Shows a success banner at the top of the screen.
    ///
    /// - Parameters:
    ///   - title: A short title (e.g. "Texte corrige", "Texte traduit").
    ///   - resultText: The corrected or translated text to preview.
    ///   - duration: How long the banner stays visible (default 4s).
    @MainActor
    static func show(title: String, resultText: String, duration: TimeInterval = 4) {
        dismiss()

        let panelWidth: CGFloat = 380

        let contentView = BannerContentView(title: title, resultText: resultText) {
            Self.dismiss()
        }

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.setFrameSize(hostingView.fittingSize)

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
            context.duration = 0.2
            panel.animator().alphaValue = 1
        }

        // Auto-dismiss
        let work = DispatchWorkItem {
            Task { @MainActor in Self.dismiss() }
        }
        autoDismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    /// Dismisses the banner with a fade-out animation.
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
    let onClose: () -> Void

    private let successColor = Color(red: 0.204, green: 0.780, blue: 0.349) // #34C759

    var body: some View {
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
            }

            Text(resultText)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Copie dans le presse-papier")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 380)
        .fixedSize(horizontal: false, vertical: true)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
