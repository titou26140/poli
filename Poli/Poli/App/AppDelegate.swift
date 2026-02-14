import AppKit
import ApplicationServices
import SwiftUI

/// The application delegate responsible for setting up the menu bar status item,
/// popover, global hotkeys, and orchestrating correction and translation actions.
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var settingsWindow: NSWindow?

    /// Shared application state, passed to SwiftUI views.
    let appState = AppState()

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Force-init subscription singletons early to start
        // the transaction listener and retry unsynced transactions.
        _ = StoreManager.shared
        _ = EntitlementManager.shared

        setupStatusItem()
        setupPopover()
        setupHotKeys()
        setupNotifications()
        requestPermissions()
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotKeyService.shared.unregister()
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "textformat.abc",
                accessibilityDescription: "Poli"
            )
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    // MARK: - Popover

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 480)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(appState: appState)
        )
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            appState.inputText = ClipboardService.shared.readIfAvailable() ?? ""

            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - Hot Keys

    private func setupHotKeys() {
        let hotKeyService = HotKeyService.shared

        hotKeyService.onCorrectionTriggered = { [weak self] in
            Task { @MainActor in
                await self?.handleCorrection()
            }
        }

        hotKeyService.onTranslationTriggered = { [weak self] in
            Task { @MainActor in
                await self?.handleTranslation()
            }
        }

        hotKeyService.register()
    }

    // MARK: - Notifications

    private func setupNotifications() {
        NotificationService.shared.setup()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openSettings),
            name: .openSettings,
            object: nil
        )
    }

    // MARK: - Settings Window

    @objc private func openSettings() {
        popover.performClose(nil)

        if let existing = settingsWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(rootView: SettingsView())

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Reglages"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 500, height: 560))
        window.center()
        window.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)

        settingsWindow = window
    }

    // MARK: - Accessibility

    private func requestPermissions() {
        // 1. Accessibility — required for System Events to simulate keystrokes.
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)

        // 2. Automation — required to talk to System Events via Apple Events.
        let script = NSAppleScript(source: """
            tell application "System Events" to return ""
        """)
        var error: NSDictionary?
        script?.executeAndReturnError(&error)
    }

    // MARK: - Correction

    @MainActor
    private func handleCorrection() async {
        // Read selected text via Accessibility API, fallback to Cmd+C simulation.
        let text = await ClipboardService.shared.getSelectedText() ?? ""
        guard !text.isEmpty else {
            NotificationService.shared.send(
                title: "Poli",
                body: "Aucun texte selectionne"
            )
            return
        }

        // Check entitlement and usage limits
        guard EntitlementManager.shared.canPerformAction() else {
            NotificationService.shared.send(
                title: "Poli",
                body: "Daily limit reached. Upgrade to Pro!"
            )
            return
        }

        appState.startAction(.correction)
        LoaderPanel.show(message: "Correction en cours...")

        do {
            let result = try await GrammarService.shared.correct(text: text)

            LoaderPanel.dismiss()

            // Write corrected text to clipboard
            ClipboardService.shared.write(result.corrected)

            // Auto-paste if a text field is active
            PasteService.shared.pasteIfTextFieldActive()

            // Show result banner
            let hasChanges = result.corrected != text
            ResultBanner.show(
                title: hasChanges ? "Texte corrige" : "Aucune correction",
                resultText: hasChanges ? result.corrected : "Le texte est deja correct."
            )

            // Track usage
            UsageTracker.shared.increment()

            appState.completeAction(with: result.corrected)
        } catch {
            LoaderPanel.dismiss()

            NotificationService.shared.send(
                title: "Poli -- Error",
                body: error.localizedDescription
            )
            appState.failAction(with: error)
        }
    }

    // MARK: - Translation

    @MainActor
    private func handleTranslation() async {
        // Read selected text via Accessibility API, fallback to Cmd+C simulation.
        let text = await ClipboardService.shared.getSelectedText() ?? ""
        guard !text.isEmpty else {
            NotificationService.shared.send(
                title: "Poli",
                body: "Aucun texte selectionne"
            )
            return
        }

        guard EntitlementManager.shared.canPerformAction() else {
            NotificationService.shared.send(
                title: "Poli",
                body: "Daily limit reached. Upgrade to Pro!"
            )
            return
        }

        appState.startAction(.translation)
        LoaderPanel.show(message: "Traduction en cours...")

        do {
            let targetLanguage = UserDefaults.standard
                .string(forKey: Constants.UserDefaultsKey.targetLanguage)
                .flatMap { SupportedLanguage(rawValue: $0) }
                ?? Constants.defaultTargetLanguage

            let result = try await TranslationService.shared.translate(
                text: text,
                targetLanguage: targetLanguage
            )

            LoaderPanel.dismiss()

            // Write translated text to clipboard
            ClipboardService.shared.write(result.translated)

            // Auto-paste if a text field is active
            PasteService.shared.pasteIfTextFieldActive()

            // Show result banner
            let sourceFlag = SupportedLanguage(rawValue: result.sourceLanguage)?.flag ?? ""
            let targetFlag = targetLanguage.flag
            ResultBanner.show(
                title: "\(sourceFlag) \u{2192} \(targetFlag) Traduit",
                resultText: result.translated
            )

            // Track usage
            UsageTracker.shared.increment()

            appState.completeAction(with: result.translated)
        } catch {
            LoaderPanel.dismiss()

            NotificationService.shared.send(
                title: "Poli -- Error",
                body: error.localizedDescription
            )
            appState.failAction(with: error)
        }
    }
}
