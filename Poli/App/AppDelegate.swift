import AppKit
import ApplicationServices
import SwiftUI
import UserNotifications

/// The application delegate responsible for setting up the menu bar status item,
/// popover, global hotkeys, and orchestrating correction and translation actions.
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    // MARK: - Properties

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?

    /// Shared application state, passed to SwiftUI views.
    let appState = AppState()

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set the app icon early so notifications and other system UI
        // display it correctly, even in .accessory (menu bar only) mode.
        NSApp.applicationIconImage = NSImage(named: "AppIcon")

        // Force-init subscription singletons early to start
        // the transaction listener and retry unsynced transactions.
        _ = StoreManager.shared
        _ = EntitlementManager.shared

        setupStatusItem()
        setupPopover()
        setupHotKeys()
        setupNotifications()
        showOnboardingIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotKeyService.shared.unregister()
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            let icon = NSImage(named: "MenuBarIcon")
            icon?.isTemplate = true
            button.image = icon
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

            NotificationCenter.default.post(name: .popoverDidOpen, object: nil)
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

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOnboardingCompleted),
            name: .onboardingCompleted,
            object: nil
        )
    }

    @objc private func handleOnboardingCompleted() {
        onboardingWindow?.close()
        onboardingWindow = nil
        AuthManager.shared.restoreSession()
        updateActivationPolicy()
    }

    // MARK: - Dock Visibility

    /// Show in Dock when a window is open, hide when all windows are closed.
    private func updateActivationPolicy() {
        let hasVisibleWindow = (settingsWindow != nil) || (onboardingWindow != nil)

        let newPolicy: NSApplication.ActivationPolicy = hasVisibleWindow ? .regular : .accessory
        if NSApp.activationPolicy() != newPolicy {
            NSApp.setActivationPolicy(newPolicy)
            if newPolicy == .regular {
                NSApp.applicationIconImage = NSImage(named: "AppIcon")
                NSApp.activate()
            }
        }
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow else { return }

        if closingWindow === settingsWindow {
            settingsWindow = nil
        } else if closingWindow === onboardingWindow {
            onboardingWindow = nil
        }

        // Defer so the window finishes closing before we check visibility.
        DispatchQueue.main.async { [weak self] in
            self?.updateActivationPolicy()
        }
    }

    // MARK: - Settings Window

    @objc private func openSettings() {
        popover.performClose(nil)

        if let existing = settingsWindow, existing.isVisible {
            NSApp.activate()
            existing.orderFrontRegardless()
            existing.makeKey()
            return
        }

        let hostingController = NSHostingController(rootView: SettingsView())

        let window = NSWindow(contentViewController: hostingController)
        window.title = String(localized: "settings.title")
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 500, height: 560))
        window.delegate = self
        window.center()

        settingsWindow = window
        updateActivationPolicy()

        window.orderFrontRegardless()
        window.makeKey()
    }

    // MARK: - Onboarding

    private func showOnboardingIfNeeded() {
        let hasCompleted = UserDefaults.standard.bool(
            forKey: Constants.UserDefaultsKey.hasCompletedOnboarding
        )

        if hasCompleted {
            // Onboarding already completed — check if permissions are still OK.
            let accessibilityOK = AXIsProcessTrusted()

            if !accessibilityOK {
                // Re-show onboarding starting at the accessibility step.
                presentOnboarding(initialStep: 2)
            } else {
                // All good — restore session now.
                AuthManager.shared.restoreSession()
            }
            return
        }

        // First launch — show full onboarding.
        presentOnboarding(initialStep: 0)
    }

    private func presentOnboarding(initialStep: Int) {
        let hostingController = NSHostingController(
            rootView: OnboardingView(initialStep: initialStep)
        )

        let window = NSWindow(contentViewController: hostingController)
        window.title = String(localized: "onboarding.window.title")
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.setContentSize(NSSize(width: 520, height: 620))
        window.delegate = self
        window.center()

        onboardingWindow = window
        updateActivationPolicy()

        window.orderFrontRegardless()
        window.makeKey()
    }

    // MARK: - Correction

    @MainActor
    private func handleCorrection() async {
        // Read selected text via Accessibility API, fallback to Cmd+C simulation.
        let text = await ClipboardService.shared.getSelectedText() ?? ""
        guard !text.isEmpty else {
            NotificationService.shared.send(
                title: "Poli",
                body: String(localized: "notification.no_text_selected")
            )
            return
        }

        // Check entitlement and usage limits
        guard EntitlementManager.shared.canPerformAction() else {
            NotificationService.shared.send(
                title: "Poli",
                body: String(localized: "notification.limit_reached")
            )
            return
        }

        appState.startAction(.correction)
        LoaderPanel.show(message: String(localized: "loader.correction"))

        do {
            let result = try await GrammarService.shared.correct(text: text)

            LoaderPanel.dismiss()

            // Write corrected text to clipboard
            ClipboardService.shared.write(result.corrected)

            // Auto-paste if a text field is active
            PasteService.shared.pasteIfTextFieldActive()

            // Show result banner with learning tips
            let hasChanges = result.corrected != text
            ResultBanner.show(
                title: hasChanges ? String(localized: "result.corrected") : String(localized: "result.no_correction"),
                resultText: hasChanges ? result.corrected : String(localized: "result.already_correct"),
                correctionErrors: result.errors
            )

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
                body: String(localized: "notification.no_text_selected")
            )
            return
        }

        guard EntitlementManager.shared.canPerformAction() else {
            NotificationService.shared.send(
                title: "Poli",
                body: String(localized: "notification.limit_reached")
            )
            return
        }

        appState.startAction(.translation)
        LoaderPanel.show(message: String(localized: "loader.translation"))

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

            // Show result banner with learning tips
            let sourceFlag = SupportedLanguage(rawValue: result.sourceLanguage)?.flag ?? ""
            let targetFlag = targetLanguage.flag
            ResultBanner.show(
                title: "\(sourceFlag) \u{2192} \(targetFlag) \(String(localized: "result.translated"))",
                resultText: result.translated,
                translationTips: result.tips
            )

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
