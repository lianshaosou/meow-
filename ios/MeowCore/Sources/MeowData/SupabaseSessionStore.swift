import Foundation
import MeowDomain

#if canImport(Security)
import Security
#endif

public actor SupabaseSessionStore {
    public struct StoredSession: Sendable, Equatable, Codable {
        public let authSession: AuthSession
        public let accessToken: String
        public let refreshToken: String?

        public init(authSession: AuthSession, accessToken: String, refreshToken: String?) {
            self.authSession = authSession
            self.accessToken = accessToken
            self.refreshToken = refreshToken
        }
    }

    private var storedSession: StoredSession?
    private let userDefaults: UserDefaults
    private let storageKey: String
    private let preferKeychain: Bool

    public init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = "meow.supabase.session",
        preferKeychain: Bool = true
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        self.preferKeychain = preferKeychain

        if let data = Self.loadData(storageKey: storageKey, userDefaults: userDefaults, preferKeychain: preferKeychain),
           let decoded = try? JSONDecoder().decode(StoredSession.self, from: data) {
            self.storedSession = decoded
        }
    }

    public func set(_ session: StoredSession) {
        storedSession = session
        guard let encoded = try? JSONEncoder().encode(session) else { return }
        Self.persistData(encoded, storageKey: storageKey, userDefaults: userDefaults, preferKeychain: preferKeychain)
    }

    public func current() -> StoredSession? {
        storedSession
    }

    public func clear() {
        storedSession = nil
        Self.clearData(storageKey: storageKey, userDefaults: userDefaults, preferKeychain: preferKeychain)
    }

    private static func loadData(storageKey: String, userDefaults: UserDefaults, preferKeychain: Bool) -> Data? {
#if canImport(Security)
        if preferKeychain, let keychainData = KeychainStorage.load(key: storageKey) {
            return keychainData
        }
#endif
        return userDefaults.data(forKey: storageKey)
    }

    private static func persistData(_ data: Data, storageKey: String, userDefaults: UserDefaults, preferKeychain: Bool) {
#if canImport(Security)
        if preferKeychain {
            let didSave = KeychainStorage.save(data: data, key: storageKey)
            if didSave {
                userDefaults.removeObject(forKey: storageKey)
                return
            }
        }
#endif
        userDefaults.set(data, forKey: storageKey)
    }

    private static func clearData(storageKey: String, userDefaults: UserDefaults, preferKeychain: Bool) {
#if canImport(Security)
        if preferKeychain {
            KeychainStorage.delete(key: storageKey)
        }
#endif
        userDefaults.removeObject(forKey: storageKey)
    }
}

#if canImport(Security)
private enum KeychainStorage {
    static func save(data: Data, key: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "com.meow.session",
            kSecAttrAccount: key
        ]

        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData] = data
        attributes[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(attributes as CFDictionary, nil)
        return status == errSecSuccess
    }

    static func load(key: String) -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "com.meow.session",
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    static func delete(key: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "com.meow.session",
            kSecAttrAccount: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
#endif
