import AppKit

/// Provides read and write access to the system clipboard (pasteboard).
final class ClipboardService {

    static let shared = ClipboardService()

    private let pasteboard = NSPasteboard.general

    private init() {}

    // MARK: - Public API

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

    /// Copies the currently selected text from the frontmost application via System Events (Cmd+C),
    /// then reads the clipboard.
    func getSelectedText() async -> String? {
        // Wait until modifier keys (Option, Shift, etc.) are fully released,
        // otherwise the Cmd+C gets merged with held keys and fails.
        await waitForModifiersRelease()

        let previousChangeCount = pasteboard.changeCount

        let script = NSAppleScript(source: """
            tell application "System Events"
                key code 8 using command down
            end tell
        """)

        var error: NSDictionary?
        script?.executeAndReturnError(&error)

        if let error {
            print("[Clipboard] System Events error: \(error[NSAppleScript.errorBriefMessage] ?? error)")
            return nil
        }

        // Wait for the pasteboard to update (up to 500ms)
        for _ in 0..<10 {
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            if pasteboard.changeCount != previousChangeCount {
                let text = readIfAvailable()
                print("[Clipboard] Got selected text (\(text?.count ?? 0) chars)")
                return text
            }
        }

        print("[Clipboard] Pasteboard did not change after Cmd+C")
        return nil
    }

    /// Polls the hardware keyboard state until all modifier keys are released (up to 1s).
    private func waitForModifiersRelease() async {
        let modifiersToCheck: CGEventFlags = [.maskShift, .maskAlternate, .maskControl, .maskCommand]

        for _ in 0..<20 { // up to 1s (20 × 50ms)
            let currentFlags = CGEventSource.flagsState(.hidSystemState)
            if currentFlags.intersection(modifiersToCheck).isEmpty {
                print("[Clipboard] Modifiers released")
                return
            }
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
        print("[Clipboard] Warning: modifiers still held after 1s, proceeding anyway")
    }
}
