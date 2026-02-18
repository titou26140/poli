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
    private var paywallWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var clickOutsideMonitor: Any?

    /// Shared application state, passed to SwiftUI views.
    let appState = AppState()

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start as a menu bar-only app (no Dock icon).
        NSApp.setActivationPolicy(.accessory)

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
        NotificationCenter.default.removeObserver(self)
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
            closePopover()
        } else {
            appState.inputText = ClipboardService.shared.readIfAvailable() ?? ""

            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()

            startClickOutsideMonitor()
            NotificationCenter.default.post(name: .popoverDidOpen, object: nil)
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        stopClickOutsideMonitor()
    }

    private func startClickOutsideMonitor() {
        stopClickOutsideMonitor()
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            guard let self, self.popover.isShown else { return }
            self.closePopover()
        }
    }

    private func stopClickOutsideMonitor() {
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
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
            selector: #selector(closeSettingsWindow),
            name: .closeSettings,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openPaywallFromNotification),
            name: .openPaywall,
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
        let hasVisibleWindow = (settingsWindow != nil) || (paywallWindow != nil) || (onboardingWindow != nil)

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
        } else if closingWindow === paywallWindow {
            paywallWindow = nil
        } else if closingWindow === onboardingWindow {
            onboardingWindow = nil
        }

        // Defer so the window finishes closing before we check visibility.
        DispatchQueue.main.async { [weak self] in
            self?.updateActivationPolicy()
        }
    }

    // MARK: - Settings Window

    @objc private func closeSettingsWindow() {
        settingsWindow?.close()
    }

    @objc private func openSettings() {
        closePopover()

        if let existing = settingsWindow {
            if existing.isMiniaturized {
                existing.deminiaturize(nil)
            }
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

        DispatchQueue.main.async {
            window.orderFrontRegardless()
            window.makeKey()
            NSApp.activate()
        }
    }

    // MARK: - Paywall Window

    @objc private func openPaywallFromNotification() {
        openPaywall(upgradePrompted: true)
    }

    private func openPaywall(upgradePrompted: Bool = false) {
        closePopover()

        // Close existing paywall so context (upgradePrompted) is refreshed.
        if let existing = paywallWindow {
            existing.close()
            paywallWindow = nil
        }

        let hostingController = NSHostingController(
            rootView: PaywallView(upgradePrompted: upgradePrompted)
        )

        let window = NSWindow(contentViewController: hostingController)
        window.title = String(localized: "paywall.title")
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 440, height: 620))
        window.delegate = self
        window.center()

        paywallWindow = window
        updateActivationPolicy()

        DispatchQueue.main.async {
            window.orderFrontRegardless()
            window.makeKey()
            NSApp.activate()
        }
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

        // Defer so macOS finishes the .accessory → .regular policy switch
        // before we attempt to bring the window to the front.
        DispatchQueue.main.async {
            window.orderFrontRegardless()
            window.makeKey()
            NSApp.activate()
        }
    }

    // MARK: - Shared Action Flow

    /// Common flow for hotkey-triggered actions: get selected text, check
    /// entitlement, show loader, execute, write to clipboard, auto-paste,
    /// show banner, handle errors.
    @MainActor
    private func performAction(
        type: ActionType,
        loaderMessage: String,
        execute: (String) async throws -> (text: String, banner: () -> Void)
    ) async {
        guard AXIsProcessTrusted() else {
            NotificationService.shared.send(
                title: "Poli",
                body: String(localized: "notification.accessibility_required")
            )
            return
        }

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
            openPaywall(upgradePrompted: true)
            return
        }

        appState.startAction(type)
        LoaderPanel.show(message: loaderMessage)

        do {
            let result = try await execute(text)

            LoaderPanel.dismiss()
            ClipboardService.shared.write(result.text)
            await PasteService.shared.pasteIfTextFieldActive()
            result.banner()
            appState.completeAction(with: result.text)
        } catch {
            LoaderPanel.dismiss()
            NotificationService.shared.send(
                title: "Poli -- Error",
                body: error.localizedDescription
            )
            appState.failAction(with: error)
        }
    }

    // MARK: - Correction

    @MainActor
    private func handleCorrection() async {
        await performAction(
            type: .correction,
            loaderMessage: String(localized: "loader.correction")
        ) { text in
            let result = try await GrammarService.shared.correct(text: text)
            let hasChanges = result.corrected != text
            return (
                text: result.corrected,
                banner: {
                    ResultBanner.show(
                        title: hasChanges
                            ? String(localized: "result.corrected")
                            : String(localized: "result.no_correction"),
                        resultText: hasChanges
                            ? result.corrected
                            : String(localized: "result.already_correct"),
                        correctionErrors: result.errors
                    )
                }
            )
        }
    }

    // MARK: - Translation

    @MainActor
    private func handleTranslation() async {
        await performAction(
            type: .translation,
            loaderMessage: String(localized: "loader.translation")
        ) { text in
            let targetLanguage = UserDefaults.standard
                .string(forKey: Constants.UserDefaultsKey.targetLanguage)
                .flatMap { SupportedLanguage(rawValue: $0) }
                ?? Constants.defaultTargetLanguage

            let result = try await TranslationService.shared.translate(
                text: text,
                targetLanguage: targetLanguage
            )

            let sourceFlag = SupportedLanguage(rawValue: result.sourceLanguage)?.flag ?? ""
            let targetFlag = targetLanguage.flag
            return (
                text: result.translated,
                banner: {
                    ResultBanner.show(
                        title: "\(sourceFlag) \u{2192} \(targetFlag) \(String(localized: "result.translated"))",
                        resultText: result.translated,
                        translationTips: result.tips
                    )
                }
            )
        }
    }
}
