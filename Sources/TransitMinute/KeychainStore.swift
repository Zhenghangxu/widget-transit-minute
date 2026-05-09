import Foundation
import Security

protocol KeychainStoring {
    func readAPIKey() throws -> String?
    func saveAPIKey(_ key: String) throws
}

struct KeychainStore: KeychainStoring {
    private let service = "TransitMinute"
    private let account = "GoogleAPIKey"

    func readAPIKey() throws -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess,
              let data = item as? Data else {
            throw KeychainError.unhandled(status)
        }
        return String(data: data, encoding: .utf8)
    }

    func saveAPIKey(_ key: String) throws {
        let data = Data(key.utf8)
        var query = baseQuery()
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess {
            return
        }
        if status != errSecItemNotFound {
            throw KeychainError.unhandled(status)
        }

        query[kSecValueData as String] = data
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainError.unhandled(addStatus)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

enum KeychainError: LocalizedError {
    case unhandled(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unhandled(let status):
            "Keychain error \(status)."
        }
    }
}
