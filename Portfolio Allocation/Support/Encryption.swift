// Portfolio file encryption

import CryptoKit
import Foundation
import Security

/// Encrypts the portfolio file with AES-256-GCM, which also detects any change to the file.
enum PortfolioCrypto {
    enum Failure: LocalizedError {
        case notEncrypted
        case sealFailed

        var errorDescription: String? {
            switch self {
            case .notEncrypted: "The file isn't an encrypted portfolio."
            case .sealFailed: "The portfolio couldn't be encrypted."
            }
        }
    }

    /// Identifies (and versions) the file format.
    private static let header = Data("PFALLOC1".utf8)
    /// Bound into every encryption so ciphertext made for anything else can't pass as a portfolio.
    private static let context = Data("Portfolio Allocation portfolio v1".utf8)

    /// Header, then nonce, ciphertext and authentication tag.
    static func seal(_ plaintext: Data, with key: SymmetricKey) throws -> Data {
        let box = try AES.GCM.seal(plaintext, using: key, authenticating: context)
        guard let combined = box.combined else { throw Failure.sealFailed }
        return header + combined
    }

    static func open(_ data: Data, with key: SymmetricKey) throws -> Data {
        guard data.starts(with: header) else { throw Failure.notEncrypted }
        let box = try AES.GCM.SealedBox(combined: data.dropFirst(header.count))
        return try AES.GCM.open(box, using: key, authenticating: context)
    }
}

/// The portfolio's encryption key, kept in the login keychain. macOS only lets the app that created the item read it; any other app has to ask you first.
enum KeychainKey {
    enum Failure: LocalizedError {
        case notFound
        case keychain(OSStatus)
        case malformed

        var errorDescription: String? {
            switch self {
            case .notFound:
                "The encryption key isn't in your keychain."
            case .keychain(let status):
                (SecCopyErrorMessageString(status, nil) as String?) ?? "Keychain error \(status)."
            case .malformed:
                "The keychain item isn't a valid encryption key."
            }
        }
    }

    private static let account = "portfolio-encryption-key"

    static func load(service: String) throws -> SymmetricKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data, data.count == 32 else { throw Failure.malformed }
            return SymmetricKey(data: data)
        case errSecItemNotFound:
            throw Failure.notFound
        default:
            throw Failure.keychain(status)
        }
    }

    static func create(service: String) throws -> SymmetricKey {
        let key = SymmetricKey(size: .bits256)
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrLabel as String: "Portfolio Allocation",
            kSecAttrComment as String: "Encrypts the Portfolio Allocation data file. Deleting this item makes that file unreadable.",
            kSecValueData as String: key.withUnsafeBytes { Data($0) },
        ]
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw Failure.keychain(status) }
        return key
    }

    /// Removes the key. Any copy of a file encrypted with it cannot be opened again
    static func delete(service: String) throws {
        let status = SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ] as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw Failure.keychain(status) }
    }

    static func loadOrCreate(service: String) throws -> SymmetricKey {
        do {
            return try load(service: service)
        } catch Failure.notFound {
            return try create(service: service)
        }
    }
}
