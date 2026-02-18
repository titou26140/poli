import AppKit
import ApplicationServices

/// Pastes clipboard content into the frontmost application by simulating Cmd+V via CGEvent.
@MainActor
final class PasteService {

    static let shared = PasteService()

    private init() {}

    // MARK: - Auto-Paste

    /// Simulates Cmd+V via CGEvent to paste clipboard content into the active text field.
    /// Waits 100ms before posting the event to let the UI settle after hotkey release.
    func pasteIfTextFieldActive() async {
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)

        #if DEBUG
        print("[Paste] Pasted via CGEvent Cmd+V")
        #endif
    }
}
