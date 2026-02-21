import AppKit

/// Provides read and write access to the system clipboard (pasteboard).
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
}
