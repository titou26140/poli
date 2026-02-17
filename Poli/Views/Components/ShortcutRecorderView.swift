import HotKey
import SwiftUI

/// A shortcut recorder that captures a keyboard shortcut from the user.
///
/// Displays the current shortcut as a badge (e.g. "⌥⇧C"). When clicked,
/// enters recording mode and captures the next key event with at least one
/// modifier (⌘, ⌥, ⌃). Press Escape to cancel recording.
struct ShortcutRecorderView: View {

    let keyCode: UInt32
    let modifiers: UInt32
    let onShortcutRecorded: (_ keyCode: UInt32, _ modifiers: UInt32) -> Void

    @State private var isRecording = false
    @State private var eventMonitor: Any?

    private var displayText: String {
        KeyCombo(carbonKeyCode: keyCode, carbonModifiers: modifiers).description
    }

    var body: some View {
        Button {
            if !isRecording {
                startRecording()
            }
        } label: {
            Text(isRecording ? String(localized: "shortcut.recording_prompt") : displayText)
                .font(.system(
                    size: 13,
                    weight: isRecording ? .regular : .semibold,
                    design: .monospaced
                ))
                .foregroundStyle(isRecording ? .secondary : .primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isRecording
                              ? Color.poliPrimary.opacity(0.1)
                              : Color.primary.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(
                            isRecording
                                ? Color.poliPrimary
                                : Color.clear,
                            lineWidth: 1.5
                        )
                )
                .animation(.easeInOut(duration: 0.15), value: isRecording)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onDisappear {
            if isRecording {
                cancelRecording()
            }
        }
    }

    // MARK: - Recording

    private func startRecording() {
        HotKeyService.shared.unregister()
        isRecording = true

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Escape cancels recording
            if event.keyCode == 53 { // kVK_Escape
                cancelRecording()
                return nil
            }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let hasModifier = flags.contains(.command)
                || flags.contains(.option)
                || flags.contains(.control)

            // Require at least one real modifier (shift alone is not enough)
            guard hasModifier else { return nil }

            let carbonMods = flags.carbonFlags
            let capturedKeyCode = UInt32(event.keyCode)

            stopMonitor()
            isRecording = false
            onShortcutRecorded(capturedKeyCode, carbonMods)

            return nil
        }
    }

    private func cancelRecording() {
        stopMonitor()
        isRecording = false
        HotKeyService.shared.register()
    }

    private func stopMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
