import Foundation
import Security

enum KeychainStore {
    private static let service = "HueHouse"
    private static let account = "HueBridgeApplicationKey"

    static func read() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    static func save(_ value: String) throws {
        try delete(ignoringMissingItem: true)

        var query = baseQuery
        query[kSecValueData as String] = Data(value.utf8)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw HueAppError.bridgeRejected("Could not save the Hue Bridge application key to Keychain.")
        }
    }

    static func delete() throws {
        try delete(ignoringMissingItem: true)
    }

    private static func delete(ignoringMissingItem: Bool) throws {
        let status = SecItemDelete(baseQuery as CFDictionary)

        if status == errSecSuccess { return }
        if ignoringMissingItem, status == errSecItemNotFound { return }

        throw HueAppError.bridgeRejected("Could not remove the Hue Bridge application key from Keychain.")
    }

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
