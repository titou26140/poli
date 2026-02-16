import AppKit
import SwiftUI

/// A compact floating pill that displays a loading indicator during
/// correction or translation operations. Does not steal focus from the active app.
final class LoaderPanel {

    private static var panel: NSPanel?

    // MARK: - Public API

    @MainActor
    static func show(message: String) {
        dismiss()

        let hostingView = NSHostingView(rootView: LoaderContentView(message: message))
        hostingView.setFrameSize(hostingView.fittingSize)

        let size = hostingView.fittingSize

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: size.width, height: size.height),
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

        // Position at top center, just below the menu bar.
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - size.width / 2
            let y = screenFrame.maxY - size.height - 12
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        self.panel = panel

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 1
        }
    }

    @MainActor
    static func dismiss() {
        guard let panel else { return }
        self.panel = nil
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.close()
        })
    }
}

// MARK: - SwiftUI Content

private struct LoaderContentView: View {
    let message: String

    private let primaryColor = Color(red: 0.357, green: 0.373, blue: 0.902)

    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)

            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .fixedSize()
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
        )
    }
}
