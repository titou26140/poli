import AppKit
import HotKey

/// Manages global keyboard shortcuts for grammar correction and translation actions.
///
/// Uses the `HotKey` package (https://github.com/soffes/HotKey) to register system-wide
/// keyboard shortcuts that work regardless of which application is in the foreground.
///
/// Shortcuts are persisted in UserDefaults and can be customized by the user.
final class HotKeyService {

    static let shared = HotKeyService()

    // MARK: - Default Key Combos

    static let defaultCorrectionCombo = KeyCombo(key: .c, modifiers: [.option, .shift])
    static let defaultTranslationCombo = KeyCombo(key: .t, modifiers: [.option, .shift])

    // MARK: - Callbacks

    /// Called when the correction shortcut is pressed.
    var onCorrectionTriggered: (() -> Void)?

    /// Called when the translation shortcut is pressed.
    var onTranslationTriggered: (() -> Void)?

    // MARK: - Current Combos

    /// The currently active correction key combo.
    private(set) var correctionCombo: KeyCombo = defaultCorrectionCombo

    /// The currently active translation key combo.
    private(set) var translationCombo: KeyCombo = defaultTranslationCombo

    // MARK: - Private State

    private var correctionHotKey: HotKey?
    private var translationHotKey: HotKey?

    private init() {}

    // MARK: - Public API

    /// Registers global keyboard shortcuts from UserDefaults, falling back to defaults.
    ///
    /// Any previously registered shortcuts are unregistered first to avoid duplicates.
    func register() {
        let defaults = UserDefaults.standard

        let corrKeyCode: UInt32
        let corrModifiers: UInt32
        if defaults.object(forKey: Constants.UserDefaultsKey.correctionShortcutKeyCode) != nil {
            corrKeyCode = UInt32(defaults.integer(forKey: Constants.UserDefaultsKey.correctionShortcutKeyCode))
            corrModifiers = UInt32(defaults.integer(forKey: Constants.UserDefaultsKey.correctionShortcutModifiers))
        } else {
            corrKeyCode = Self.defaultCorrectionCombo.carbonKeyCode
            corrModifiers = Self.defaultCorrectionCombo.carbonModifiers
        }

        let transKeyCode: UInt32
        let transModifiers: UInt32
        if defaults.object(forKey: Constants.UserDefaultsKey.translationShortcutKeyCode) != nil {
            transKeyCode = UInt32(defaults.integer(forKey: Constants.UserDefaultsKey.translationShortcutKeyCode))
            transModifiers = UInt32(defaults.integer(forKey: Constants.UserDefaultsKey.translationShortcutModifiers))
        } else {
            transKeyCode = Self.defaultTranslationCombo.carbonKeyCode
            transModifiers = Self.defaultTranslationCombo.carbonModifiers
        }

        registerWithCodes(
            correctionKeyCode: corrKeyCode,
            correctionModifiers: corrModifiers,
            translationKeyCode: transKeyCode,
            translationModifiers: transModifiers
        )
    }

    /// Persists new shortcuts to UserDefaults and registers them.
    func register(
        correctionKeyCode: UInt32,
        correctionModifiers: UInt32,
        translationKeyCode: UInt32,
        translationModifiers: UInt32
    ) {
        let defaults = UserDefaults.standard
        defaults.set(Int(correctionKeyCode), forKey: Constants.UserDefaultsKey.correctionShortcutKeyCode)
        defaults.set(Int(correctionModifiers), forKey: Constants.UserDefaultsKey.correctionShortcutModifiers)
        defaults.set(Int(translationKeyCode), forKey: Constants.UserDefaultsKey.translationShortcutKeyCode)
        defaults.set(Int(translationModifiers), forKey: Constants.UserDefaultsKey.translationShortcutModifiers)

        registerWithCodes(
            correctionKeyCode: correctionKeyCode,
            correctionModifiers: correctionModifiers,
            translationKeyCode: translationKeyCode,
            translationModifiers: translationModifiers
        )
    }

    /// Resets shortcuts to defaults, clears UserDefaults, and re-registers.
    func resetToDefaults() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Constants.UserDefaultsKey.correctionShortcutKeyCode)
        defaults.removeObject(forKey: Constants.UserDefaultsKey.correctionShortcutModifiers)
        defaults.removeObject(forKey: Constants.UserDefaultsKey.translationShortcutKeyCode)
        defaults.removeObject(forKey: Constants.UserDefaultsKey.translationShortcutModifiers)
        register()
    }

    /// Unregisters all global keyboard shortcuts and releases resources.
    func unregister() {
        correctionHotKey = nil
        translationHotKey = nil
    }

    // MARK: - Private

    private func registerWithCodes(
        correctionKeyCode: UInt32,
        correctionModifiers: UInt32,
        translationKeyCode: UInt32,
        translationModifiers: UInt32
    ) {
        unregister()

        correctionCombo = KeyCombo(carbonKeyCode: correctionKeyCode, carbonModifiers: correctionModifiers)
        correctionHotKey = HotKey(keyCombo: correctionCombo)
        correctionHotKey?.keyDownHandler = { [weak self] in
            self?.onCorrectionTriggered?()
        }

        translationCombo = KeyCombo(carbonKeyCode: translationKeyCode, carbonModifiers: translationModifiers)
        translationHotKey = HotKey(keyCombo: translationCombo)
        translationHotKey?.keyDownHandler = { [weak self] in
            self?.onTranslationTriggered?()
        }
    }
}
