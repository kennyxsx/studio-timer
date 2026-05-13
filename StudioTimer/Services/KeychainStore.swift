// StudioTimer/Services/KeychainStore.swift
import Foundation
import Security

/// Wraps `kSecClassGenericPassword` Keychain access for the app's JWT tokens.
/// Tokens are stored with `kSecAttrAccessibleAfterFirstUnlock`, which makes
/// them available even when the device is locked (after the first unlock
/// post-boot) so background refresh activity works.
struct KeychainStore {
    private let service: String

    init(service: String = "de.ivy-s.studiotimer") {
        self.service = service
    }

    var accessToken: String? { read(account: "access_token") }
    var refreshToken: String? { read(account: "refresh_token") }

    func setAccessToken(_ value: String) throws {
        try write(value, account: "access_token")
    }

    func setRefreshToken(_ value: String) throws {
        try write(value, account: "refresh_token")
    }

    func clearAll() {
        delete(account: "access_token")
        delete(account: "refresh_token")
    }

    // MARK: - Private

    private func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let str = String(data: data, encoding: .utf8) else {
            return nil
        }
        return str
    }

    private func write(_ value: String, account: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encoding
        }
        // Try update first; if not found, add.
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attrs: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if updateStatus == errSecSuccess { return }
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            for (k, v) in attrs { addQuery[k] = v }
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.osStatus(addStatus)
            }
            return
        }
        throw KeychainError.osStatus(updateStatus)
    }

    private func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum KeychainError: Error {
    case encoding
    case osStatus(OSStatus)
}
