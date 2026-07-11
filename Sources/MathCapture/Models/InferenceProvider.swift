import Foundation

enum InferenceProvider: String, CaseIterable, Codable {
    case apfel
    case google
    case openAI
    case anthropic
    case gitHub

    var displayName: String {
        switch self {
        case .apfel: return "Apfel (Local)"
        case .google: return "Google Gemini"
        case .openAI: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .gitHub: return "GitHub AI"
        }
    }

    var models: [String] {
        switch self {
        case .apfel: return ["apple-foundationmodel"]
        case .google: return ["gemini-2.0-flash", "gemini-2.5-pro"]
        case .openAI: return ["gpt-4o", "gpt-4o-mini"]
        case .anthropic: return ["claude-sonnet-4-20250514", "claude-3-5-haiku-latest"]
        case .gitHub: return ["openai/gpt-4o", "openai/gpt-4o-mini", "anthropic/claude-sonnet-4-20250514", "google/gemini-2.0-flash-001"]
        }
    }

    var defaultModel: String { models[0] }

    var apiKeyLabel: String {
        switch self {
        case .apfel: return "API Key (optional — not needed for local server)"
        case .google: return "Gemini API Key"
        case .openAI: return "OpenAI API Key"
        case .anthropic: return "Anthropic API Key"
        case .gitHub: return "GitHub Token"
        }
    }
}
