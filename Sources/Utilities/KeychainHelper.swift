import Foundation
import Security

/// Helper for secure storage in macOS Keychain
enum KeychainHelper {
    
    private static let defaultService = "com.lulu-ai-companion"
    
    // MARK: - Standard Operations (our app's keychain)
    
    static func save(key: String, value: String) {
        save(service: defaultService, key: key, value: value)
    }
    
    static func get(key: String) -> String? {
        return get(service: defaultService, key: key)
    }
    
    static func delete(key: String) {
        delete(service: defaultService, key: key)
    }
    
    // MARK: - Cross-Service Operations (for reading OpenClaw's keychain)
    
    static func save(service: String, key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        
        // Delete existing item first
        delete(service: service, key: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("Keychain save error: \(status)")
        }
    }
    
    static func get(service: String, key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return value
    }
    
    static func delete(service: String, key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - Check Own Keys
    
    /// Check if we have any API keys in our own keychain (no cross-app access)
    static func hasOwnAPIKeys() -> Bool {
        if get(key: "claude_api_key") != nil { return true }
        for i in 1...5 {
            if get(key: "claude_api_key_\(i)") != nil { return true }
        }
        return false
    }
}
