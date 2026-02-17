import AppKit

/// Provides automated paste functionality via System Events (AppleScript).
final class PasteService {

    static let shared = PasteService()

    private let pasteScript = NSAppleScript(source: """
        tell application "System Events" to keystroke "v" using command down
    """)

    private var pendingPasteWork: DispatchWorkItem?

    private init() {}

    // MARK: - Auto-Paste

    /// Simulates Cmd+V via System Events to paste clipboard content into the active text field.
    func pasteIfTextFieldActive() {
        pendingPasteWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            var error: NSDictionary?
            self?.pasteScript?.executeAndReturnError(&error)
            #if DEBUG
            if let error {
                print("[Paste] System Events error: \(error[NSAppleScript.errorBriefMessage] ?? error)")
            }
            #endif
        }
        pendingPasteWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)
    }
}
