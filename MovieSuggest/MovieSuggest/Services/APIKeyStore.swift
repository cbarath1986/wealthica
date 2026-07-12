import Foundation
import Security

/// Stores the user's TMDB API key in the Keychain. Static/stateless so it
/// can be read from a non-isolated context (the TMDBClient environment
/// default) as well as from views.
enum APIKeyStore {
    private static let service = "MovieSuggest.TMDB"
    private static let account = "apiKey"

    /// The key requests should actually use: a personal key from the
    /// Keychain wins, otherwise the built-in distribution key (if this
    /// build ships one), otherwise nil — which is what gates onboarding.
    static func currentKey() -> String? {
        if let personal = personalKey() { return personal }
        return DefaultAPIKey.isConfigured ? DefaultAPIKey.key : nil
    }

    /// Only the user's own Keychain-stored key, ignoring any built-in one —
    /// lets Settings distinguish "using your key" from "using the built-in
    /// key".
    static func personalKey() -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        query.removeValue(forKey: kSecReturnData as String)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ key: String) {
        let data = Data(key.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        let status = SecItemAdd(attributes as CFDictionary, nil)
        // Never log the key itself — only whether the save succeeded.
        Log.settings.notice("APIKeyStore: save \(status == errSecSuccess ? "succeeded" : "failed", privacy: .public)")
    }

    static func remove() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        Log.settings.notice("APIKeyStore: key removed")
    }
}
