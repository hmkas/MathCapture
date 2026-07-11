import Foundation
import Security

enum OutputFormat: String, CaseIterable, Codable {
    case mathML = "MathML"
    case latex = "LaTeX"

    var displayName: String { rawValue }

    var promptInstruction: String {
        switch self {
        case .mathML: return "Return ONLY MathML"
        case .latex: return "Return ONLY LaTeX"
        }
    }

    var notificationTitle: String {
        switch self {
        case .mathML: return "MathML copied!"
        case .latex: return "LaTeX copied!"
        }
    }
}

enum SettingsStore {
    private static let keychainService = "com.maarten.mathcapture"
    private static let providerKey = "selectedProvider"
    private static let formatKey = "outputFormat"
    private static let oldAPIKeyAccount = "gemini-api-key"

    // MARK: - Output Format

    static func saveFormat(_ format: OutputFormat) {
        UserDefaults.standard.set(format.rawValue, forKey: formatKey)
    }

    static func getFormat() -> OutputFormat {
        guard let raw = UserDefaults.standard.string(forKey: formatKey),
              let format = OutputFormat(rawValue: raw) else {
            return .mathML
        }
        return format
    }

    // MARK: - Provider

    static func saveProvider(_ provider: InferenceProvider) {
        UserDefaults.standard.set(provider.rawValue, forKey: providerKey)
    }

    static func getProvider() -> InferenceProvider {
        guard let raw = UserDefaults.standard.string(forKey: providerKey),
              let provider = InferenceProvider(rawValue: raw) else {
            return .apfel
        }
        return provider
    }

    // MARK: - Model (per-provider)

    static func saveModel(_ model: String, for provider: InferenceProvider) {
        UserDefaults.standard.set(model, forKey: modelKey(for: provider))
    }

    static func getModel(for provider: InferenceProvider) -> String {
        UserDefaults.standard.string(forKey: modelKey(for: provider)) ?? provider.defaultModel
    }

    private static func modelKey(for provider: InferenceProvider) -> String {
        "\(provider.rawValue)_model"
    }

    // MARK: - API Key (per-provider)

    static func saveAPIKey(_ key: String, for provider: InferenceProvider) {
        guard let data = key.data(using: .utf8) else { return }
        deleteAPIKey(for: provider)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount(for: provider),
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    static func getAPIKey(for provider: InferenceProvider) -> String? {
        let account = keychainAccount(for: provider)

        if let key = readKeychain(account: account) {
            return key
        }

        // Migration from old single-key storage
        if provider == .google, let oldKey = readKeychain(account: oldAPIKeyAccount) {
            saveAPIKey(oldKey, for: .google)
            deleteKeychain(account: oldAPIKeyAccount)
            return oldKey
        }

        return nil
    }

    static func deleteAPIKey(for provider: InferenceProvider) {
        deleteKeychain(account: keychainAccount(for: provider))
    }

    private static func keychainAccount(for provider: InferenceProvider) -> String {
        "\(provider.rawValue)-api-key"
    }

    private static func readKeychain(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    private static func deleteKeychain(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
        ]

        SecItemDelete(query as CFDictionary)
    }
}
