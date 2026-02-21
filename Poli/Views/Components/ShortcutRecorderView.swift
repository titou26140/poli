import AppKit
import Carbon
import HotKey
import SwiftUI

/// A view that captures a global keyboard shortcut from the user.
///
/// Displays the current key combo and enters recording mode on click.
/// While recording, the next modifier+key press is captured and reported
/// via the `onChange` callback.
struct ShortcutRecorderView: View {

    let keyCode: UInt32
    let modifiers: UInt32
    let onChange: (UInt32, UInt32) -> Void

    @State private var isRecording = false
    @State private var eventMonitor: Any?

    private var displayText: String {
        if isRecording {
            return String(localized: "settings.shortcuts.recording")
        }
        return KeyCombo(carbonKeyCode: keyCode, carbonModifiers: modifiers).description
    }

    var body: some View {
        Text(displayText)
            .font(.system(size: 13, weight: .semibold, design: .monospaced))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(isRecording ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isRecording ? Color.accentColor : Color.clear, lineWidth: 1)
            )
            .onTapGesture {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            }
            .onDisappear {
                stopRecording()
            }
    }

    private func startRecording() {
        isRecording = true

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // Escape cancels recording
            if event.keyCode == UInt16(kVK_Escape) {
                stopRecording()
                return nil
            }

            // Require at least one modifier
            guard !flags.isEmpty else { return nil }

            let carbonMods = NSEvent.ModifierFlags(rawValue: flags.rawValue).carbonFlags
            let carbonKey = UInt32(event.keyCode)

            stopRecording()
            onChange(carbonKey, carbonMods)
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
