import AppKit

/// Provides automated paste functionality via System Events (AppleScript).
final class PasteService {

    static let shared = PasteService()

    private init() {}

    // MARK: - Auto-Paste

    /// Simulates Cmd+V via System Events to paste clipboard content into the active text field.
    func pasteIfTextFieldActive() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let script = NSAppleScript(source: """
                tell application "System Events" to keystroke "v" using command down
            """)
            var error: NSDictionary?
            script?.executeAndReturnError(&error)
            if let error {
                print("[Paste] System Events error: \(error[NSAppleScript.errorBriefMessage] ?? error)")
            }
        }
    }
}
