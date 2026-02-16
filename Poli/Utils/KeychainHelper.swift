import Foundation
import Security

/// Lightweight wrapper around the macOS Keychain for storing small secrets
/// (e.g. the backend authentication token).
///
/// Note: During Xcode development, each rebuild (Cmd+R) changes the
/// binary's code signature, which may trigger a one-time "allow keychain
/// access?" prompt from macOS. This is normal and does NOT happen in
/// production (Mac App Store) where the signature is stable.
final class KeychainHelper {

    // MARK: - Singleton

    static let shared = KeychainHelper()

    // MARK: - Private

    private let service: String = Constants.keychainServiceName

    private init() {}

    // MARK: - Public API

    /// Saves a UTF-8 string value in the Keychain under the given key.
    ///
    /// If an entry for the key already exists it is replaced.
    @discardableResult
    func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        // Remove any existing item first so the add never fails with a
        // duplicate-item error.
        SecItemDelete(query as CFDictionary)

        // Now insert.
        var addQuery = query
        addQuery[kSecValueData as String] = data

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Reads a UTF-8 string value from the Keychain for the given key.
    ///
    /// Returns `nil` when the key does not exist or the stored data cannot be
    /// decoded as UTF-8.
    func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    /// Deletes the Keychain entry for the given key.
    ///
    /// It is safe to call this even when the key does not exist.
    @discardableResult
    func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
