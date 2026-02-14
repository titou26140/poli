import AppKit
import HotKey

/// Manages global keyboard shortcuts for grammar correction and translation actions.
///
/// Uses the `HotKey` package (https://github.com/soffes/HotKey) to register system-wide
/// keyboard shortcuts that work regardless of which application is in the foreground.
final class HotKeyService {

    static let shared = HotKeyService()

    // MARK: - Callbacks

    /// Called when the correction shortcut (Option+Shift+C) is pressed.
    var onCorrectionTriggered: (() -> Void)?

    /// Called when the translation shortcut (Option+Shift+T) is pressed.
    var onTranslationTriggered: (() -> Void)?

    // MARK: - Private State

    private var correctionHotKey: HotKey?
    private var translationHotKey: HotKey?

    private init() {}

    // MARK: - Public API

    /// Registers global keyboard shortcuts for correction and translation.
    ///
    /// - Option+Shift+C triggers grammar correction.
    /// - Option+Shift+T triggers translation.
    ///
    /// Any previously registered shortcuts are unregistered first to avoid duplicates.
    func register() {
        unregister()

        // Option+Shift+C for correction
        correctionHotKey = HotKey(key: .c, modifiers: [.option, .shift])
        correctionHotKey?.keyDownHandler = { [weak self] in
            self?.onCorrectionTriggered?()
        }

        // Option+Shift+T for translation
        translationHotKey = HotKey(key: .t, modifiers: [.option, .shift])
        translationHotKey?.keyDownHandler = { [weak self] in
            self?.onTranslationTriggered?()
        }
    }

    /// Unregisters all global keyboard shortcuts and releases resources.
    func unregister() {
        correctionHotKey = nil
        translationHotKey = nil
    }
}
