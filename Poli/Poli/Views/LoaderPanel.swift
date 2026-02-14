import AppKit
import SwiftUI

/// A floating, non-activating panel that displays a loading indicator during
/// correction or translation operations. Does not steal focus from the active app.
final class LoaderPanel {

    // MARK: - Singleton

    private static var panel: NSPanel?

    // MARK: - Public API

    /// Shows the loader panel centered on the main screen with the given message.
    @MainActor
    static func show(message: String) {
        dismiss()

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 120),
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

        let hostingView = NSHostingView(rootView: LoaderContentView(message: message))
        panel.contentView = hostingView

        // Center on main screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - 100
            let y = screenFrame.midY - 60
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.orderFrontRegardless()
        self.panel = panel
    }

    /// Dismisses the loader panel if it is currently visible.
    @MainActor
    static func dismiss() {
        panel?.close()
        panel = nil
    }
}

// MARK: - SwiftUI Content

private struct LoaderContentView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(width: 200, height: 120)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
