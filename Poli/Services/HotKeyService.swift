import AppKit
import HotKey

/// Manages global keyboard shortcuts for correction and translation actions.
///
/// Persists custom key combos to UserDefaults and restores them on launch.
/// Defaults: Option+Shift+C (correction), Option+Shift+T (translation).
final class HotKeyService {

    static let shared = HotKeyService()

    // MARK: - Default Combos

    static let defaultCorrectionCombo = KeyCombo(key: .c, modifiers: [.option, .shift])
    static let defaultTranslationCombo = KeyCombo(key: .t, modifiers: [.option, .shift])

    // MARK: - Callbacks

    var onCorrectionTriggered: (() -> Void)?
    var onTranslationTriggered: (() -> Void)?

    // MARK: - Current Combos

    private(set) var correctionCombo: KeyCombo
    private(set) var translationCombo: KeyCombo

    // MARK: - HotKey Instances

    private var correctionHotKey: HotKey?
    private var translationHotKey: HotKey?

    // MARK: - Init

    private init() {
        correctionCombo = Self.loadCombo(
            keyCodeKey: Constants.UserDefaultsKey.correctionShortcutKeyCode,
            modifiersKey: Constants.UserDefaultsKey.correctionShortcutModifiers,
            default: Self.defaultCorrectionCombo
        )
        translationCombo = Self.loadCombo(
            keyCodeKey: Constants.UserDefaultsKey.translationShortcutKeyCode,
            modifiersKey: Constants.UserDefaultsKey.translationShortcutModifiers,
            default: Self.defaultTranslationCombo
        )
    }

    // MARK: - Registration

    /// Register hotkeys using the current combos (loaded from UserDefaults or defaults).
    func register() {
        register(
            correctionKeyCode: correctionCombo.carbonKeyCode,
            correctionModifiers: correctionCombo.carbonModifiers,
            translationKeyCode: translationCombo.carbonKeyCode,
            translationModifiers: translationCombo.carbonModifiers
        )
    }

    /// Register hotkeys with specific key codes and modifiers. Saves to UserDefaults.
    func register(
        correctionKeyCode: UInt32,
        correctionModifiers: UInt32,
        translationKeyCode: UInt32,
        translationModifiers: UInt32
    ) {
        unregister()

        let corrCombo = KeyCombo(carbonKeyCode: correctionKeyCode, carbonModifiers: correctionModifiers)
        let transCombo = KeyCombo(carbonKeyCode: translationKeyCode, carbonModifiers: translationModifiers)

        correctionCombo = corrCombo
        translationCombo = transCombo

        saveCombo(corrCombo,
                  keyCodeKey: Constants.UserDefaultsKey.correctionShortcutKeyCode,
                  modifiersKey: Constants.UserDefaultsKey.correctionShortcutModifiers)
        saveCombo(transCombo,
                  keyCodeKey: Constants.UserDefaultsKey.translationShortcutKeyCode,
                  modifiersKey: Constants.UserDefaultsKey.translationShortcutModifiers)

        correctionHotKey = HotKey(keyCombo: corrCombo)
        correctionHotKey?.keyDownHandler = { [weak self] in
            self?.onCorrectionTriggered?()
        }

        translationHotKey = HotKey(keyCombo: transCombo)
        translationHotKey?.keyDownHandler = { [weak self] in
            self?.onTranslationTriggered?()
        }
    }

    /// Unregister all hotkeys.
    func unregister() {
        correctionHotKey = nil
        translationHotKey = nil
    }

    /// Reset shortcuts to defaults and re-register.
    func resetToDefaults() {
        register(
            correctionKeyCode: Self.defaultCorrectionCombo.carbonKeyCode,
            correctionModifiers: Self.defaultCorrectionCombo.carbonModifiers,
            translationKeyCode: Self.defaultTranslationCombo.carbonKeyCode,
            translationModifiers: Self.defaultTranslationCombo.carbonModifiers
        )
    }

    // MARK: - Persistence

    private static func loadCombo(keyCodeKey: String, modifiersKey: String, default fallback: KeyCombo) -> KeyCombo {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: keyCodeKey) != nil else { return fallback }
        let keyCode = UInt32(defaults.integer(forKey: keyCodeKey))
        let modifiers = UInt32(defaults.integer(forKey: modifiersKey))
        return KeyCombo(carbonKeyCode: keyCode, carbonModifiers: modifiers)
    }

    private func saveCombo(_ combo: KeyCombo, keyCodeKey: String, modifiersKey: String) {
        let defaults = UserDefaults.standard
        defaults.set(Int(combo.carbonKeyCode), forKey: keyCodeKey)
        defaults.set(Int(combo.carbonModifiers), forKey: modifiersKey)
    }
}
