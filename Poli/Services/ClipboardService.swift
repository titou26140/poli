import AppKit
import ApplicationServices

/// Provides read and write access to the system clipboard (pasteboard)
/// and retrieves selected text from the frontmost application.
final class ClipboardService {

    static let shared = ClipboardService()

    private let pasteboard = NSPasteboard.general

    private init() {}

    // MARK: - Clipboard

    /// Reads the current text content from the system clipboard.
    func read() -> String? {
        pasteboard.string(forType: .string)
    }

    /// Writes the given text to the system clipboard, replacing any existing content.
    func write(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Reads the clipboard content and returns a trimmed, non-empty string, or `nil`.
    func readIfAvailable() -> String? {
        guard let text = read() else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }

    // MARK: - Get Selected Text

    /// Copies the currently selected text by simulating Cmd+C via CGEvent,
    /// then reads the clipboard.
    func getSelectedText() async -> String? {
        await waitForModifiersRelease()

        // Save current clipboard content to restore if no text is selected
        let savedClipboard = pasteboard.string(forType: .string)
        let previousChangeCount = pasteboard.changeCount

        // Simulate Cmd+C via CGEvent (session event tap works in sandbox)
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)

        // Wait for the pasteboard to update (up to 500ms)
        for _ in 0..<10 {
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            if pasteboard.changeCount != previousChangeCount {
                let text = readIfAvailable()
                #if DEBUG
                print("[Clipboard] Got selected text via CGEvent (\(text?.count ?? 0) chars)")
                #endif
                return text
            }
        }

        // No text was selected — restore the previous clipboard content
        if let saved = savedClipboard {
            write(saved)
        }

        #if DEBUG
        print("[Clipboard] Pasteboard did not change after CGEvent Cmd+C")
        #endif
        return nil
    }

    /// Polls the hardware keyboard state until all modifier keys are released (up to 1s).
    private func waitForModifiersRelease() async {
        let modifiersToCheck: CGEventFlags = [.maskShift, .maskAlternate, .maskControl, .maskCommand]

        for _ in 0..<20 { // up to 1s (20 × 50ms)
            let currentFlags = CGEventSource.flagsState(.hidSystemState)
            if currentFlags.intersection(modifiersToCheck).isEmpty {
                #if DEBUG
                print("[Clipboard] Modifiers released")
                #endif
                return
            }
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
        #if DEBUG
        print("[Clipboard] Warning: modifiers still held after 1s, proceeding anyway")
        #endif
    }
}
