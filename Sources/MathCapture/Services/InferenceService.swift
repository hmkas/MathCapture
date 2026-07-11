import Foundation
import AppKit

actor InferenceService {
    static let shared = InferenceService()
    private let session = URLSession.shared

    func recognizeFormula(image: CGImage) async throws -> String {
        let provider = SettingsStore.getProvider()

        if provider == .apfel {
            return try await recognizeWithApfel(image: image)
        }

        guard let apiKey = SettingsStore.getAPIKey(for: provider), !apiKey.isEmpty else {
            throw MathError.noAPIKey
        }

        let model = SettingsStore.getModel(for: provider)
        let format = SettingsStore.getFormat()
        let base64 = try encodeImage(image)
        let prompt = "\(format.promptInstruction) for the mathematical formula in this image. No explanations, no markdown formatting."

        let (url, httpBody, headers) = try buildRequest(provider: provider, model: model, apiKey: apiKey, base64: base64, text: prompt)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = httpBody
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MathError.networkError
        }

        guard httpResponse.statusCode == 200 else {
            throw apiError(from: data, statusCode: httpResponse.statusCode)
        }

        let text = try parseResponse(provider: provider, data: data)

        guard !text.isEmpty else {
            throw MathError.noFormulaDetected
        }

        return extractFencedContent(from: text)
    }

    func testAPIKey(_ apiKey: String, for provider: InferenceProvider) async throws {
        if provider == .apfel {
            try await testApfelServer()
            return
        }

        let model = provider.defaultModel

        let (url, httpBody, headers) = try buildRequest(provider: provider, model: model, apiKey: apiKey, base64: nil, text: "Say OK")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = httpBody
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MathError.networkError
        }

        guard httpResponse.statusCode == 200 else {
            throw apiError(from: data, statusCode: httpResponse.statusCode)
        }

        let text = try parseResponse(provider: provider, data: data)

        guard text.trimmingCharacters(in: .whitespacesAndNewlines) == "OK" else {
            throw MathError.unexpectedResponse(String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(100)))
        }
    }

    private func testApfelServer() async throws {
        let apfelURL = try apfelBinary()
        let process = Process()
        process.executableURL = apfelURL
        process.arguments = ["--max-tokens", "16", "Say OK"]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let msg = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown error"
            throw MathError.serverError("apfel test failed: \(msg)")
        }
    }

    private func recognizeWithApfel(image: CGImage) async throws -> String {
        let format = SettingsStore.getFormat()
        let prompt = "\(format.promptInstruction) for the mathematical formula in this image. No explanations, no markdown formatting."

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mathcapture_\(UUID().uuidString).jpg")
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        guard let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            throw MathError.imageConversionFailed
        }
        try jpegData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let apfelURL = try apfelBinary()

        let process = Process()
        process.executableURL = apfelURL
        process.arguments = ["-f", tempURL.path, "--max-tokens", "512", prompt]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let msg = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown error"
            throw MathError.serverError("Apfel failed: \(msg)")
        }

        guard !output.isEmpty else {
            throw MathError.noFormulaDetected
        }

        return extractFencedContent(from: output)
    }

    private func apfelBinary() throws -> URL {
        let candidates = [
            "/opt/homebrew/bin/apfel",
            "/usr/local/bin/apfel",
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        let which = Process()
        which.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        which.arguments = ["which", "apfel"]
        let pipe = Pipe()
        which.standardOutput = pipe
        try which.run()
        which.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let path = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty,
           FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        throw MathError.serverError("apfel not found. Install with: brew install apfel")
    }

    private func encodeImage(_ image: CGImage) throws -> String {
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        guard let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            throw MathError.imageConversionFailed
        }
        return jpegData.base64EncodedString()
    }

    private func buildRequest(provider: InferenceProvider, model: String, apiKey: String, base64: String?, text: String) throws -> (URL, Data, [String: String]) {
        switch provider {
        case .google:
            var parts: [Part] = []
            if let base64 {
                parts.append(Part(inlineData: InlineData(mimeType: "image/jpeg", data: base64)))
            }
            parts.append(Part(text: text))
            let body = GeminiRequest(contents: [Content(parts: parts)])
            let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!
            return (url, try JSONEncoder().encode(body), [:])

        case .openAI:
            var content: [OpenAIContent] = []
            if let base64 {
                content.append(OpenAIContent(type: "image_url", text: nil, imageUrl: OpenAIImageUrl(url: "data:image/jpeg;base64,\(base64)")))
            }
            content.append(OpenAIContent(type: "text", text: text, imageUrl: nil))
            let body = OpenAIRequest(model: model, messages: [OpenAIMessage(role: "user", content: content)], maxTokens: 4096)
            let url = URL(string: "https://api.openai.com/v1/chat/completions")!
            return (url, try JSONEncoder().encode(body), ["Authorization": "Bearer \(apiKey)"])

        case .anthropic:
            var content: [AnthropicContent] = []
            if let base64 {
                content.append(AnthropicContent(type: "image", text: nil, source: AnthropicImageSource(type: "base64", mediaType: "image/jpeg", data: base64)))
            }
            content.append(AnthropicContent(type: "text", text: text, source: nil))
            let body = AnthropicRequest(model: model, maxTokens: 4096, messages: [AnthropicMessage(role: "user", content: content)])
            let url = URL(string: "https://api.anthropic.com/v1/messages")!
            return (url, try JSONEncoder().encode(body), [
                "x-api-key": apiKey,
                "anthropic-version": "2023-06-01",
            ])

        case .gitHub:
            var content: [OpenAIContent] = []
            if let base64 {
                content.append(OpenAIContent(type: "image_url", text: nil, imageUrl: OpenAIImageUrl(url: "data:image/jpeg;base64,\(base64)")))
            }
            content.append(OpenAIContent(type: "text", text: text, imageUrl: nil))
            let body = OpenAIRequest(model: model, messages: [OpenAIMessage(role: "user", content: content)], maxTokens: 4096)
            let url = URL(string: "https://models.github.ai/inference/chat/completions")!
            return (url, try JSONEncoder().encode(body), ["Authorization": "Bearer \(apiKey)"])

        case .apfel:
            var content: [OpenAIContent] = []
            if let base64 {
                content.append(OpenAIContent(type: "image_url", text: nil, imageUrl: OpenAIImageUrl(url: "data:image/jpeg;base64,\(base64)")))
            }
            content.append(OpenAIContent(type: "text", text: text, imageUrl: nil))
            let body = OpenAIRequest(model: model, messages: [OpenAIMessage(role: "user", content: content)], maxTokens: 4096)
            let url = URL(string: "http://localhost:11434/v1/chat/completions")!
            var headers: [String: String] = [:]
            if !apiKey.isEmpty {
                headers["Authorization"] = "Bearer \(apiKey)"
            }
            return (url, try JSONEncoder().encode(body), headers)
        }
    }

    private func parseResponse(provider: InferenceProvider, data: Data) throws -> String {
        switch provider {
        case .google:
            let response = try JSONDecoder().decode(GeminiResponse.self, from: data)
            return response.candidates?.first?.content.parts.first?.text ?? ""

        case .openAI:
            let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            return response.choices?.first?.message.content ?? ""

        case .anthropic:
            let response = try JSONDecoder().decode(AnthropicResponse.self, from: data)
            return response.content?.first(where: { $0.type == "text" })?.text ?? ""

        case .gitHub:
            let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            return response.choices?.first?.message.content ?? ""

        case .apfel:
            let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            return response.choices?.first?.message.content ?? ""
        }
    }

    private func apiError(from data: Data, statusCode: Int) -> MathError {
        struct ErrorBody: Decodable {
            struct ErrorDetail: Decodable {
                let message: String?
            }
            let error: ErrorDetail?
        }

        if let errorBody = try? JSONDecoder().decode(ErrorBody.self, from: data),
           let message = errorBody.error?.message {
            return .serverError(message)
        }

        if statusCode == 400 || statusCode == 403 {
            return .invalidAPIKey
        }

        return .apiError(statusCode: statusCode)
    }

    private func extractFencedContent(from text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)

        let lines = result.components(separatedBy: .newlines)
        var filtered = lines
        if filtered.first?.hasPrefix("```") == true {
            filtered.removeFirst()
        }
        if filtered.last?.trimmingCharacters(in: .whitespacesAndNewlines) == "```" {
            filtered.removeLast()
        }
        result = filtered.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        return result
    }
}

// MARK: - OpenAI models

private struct OpenAIRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case model, messages
        case maxTokens = "max_tokens"
    }
}

private struct OpenAIMessage: Codable {
    let role: String
    let content: [OpenAIContent]
}

private struct OpenAIContent: Codable {
    let type: String
    let text: String?
    let imageUrl: OpenAIImageUrl?

    enum CodingKeys: String, CodingKey {
        case type, text
        case imageUrl = "image_url"
    }
}

private struct OpenAIImageUrl: Codable {
    let url: String
}

private struct OpenAIResponse: Codable {
    let choices: [OpenAIChoice]?
}

private struct OpenAIChoice: Codable {
    let message: OpenAIMessageContent
}

private struct OpenAIMessageContent: Codable {
    let content: String?
}

// MARK: - Anthropic models

private struct AnthropicRequest: Codable {
    let model: String
    let maxTokens: Int
    let messages: [AnthropicMessage]

    enum CodingKeys: String, CodingKey {
        case model, messages
        case maxTokens = "max_tokens"
    }
}

private struct AnthropicMessage: Codable {
    let role: String
    let content: [AnthropicContent]
}

private struct AnthropicContent: Codable {
    let type: String
    let text: String?
    let source: AnthropicImageSource?
}

private struct AnthropicImageSource: Codable {
    let type: String
    let mediaType: String
    let data: String

    enum CodingKeys: String, CodingKey {
        case type
        case mediaType = "media_type"
        case data
    }
}

private struct AnthropicResponse: Codable {
    let content: [AnthropicResponseContent]?
}

private struct AnthropicResponseContent: Codable {
    let type: String
    let text: String?
}

// MARK: - Shared error type

enum MathError: LocalizedError {
    case noAPIKey
    case imageConversionFailed
    case networkError
    case invalidAPIKey
    case serverError(String)
    case apiError(statusCode: Int)
    case noFormulaDetected
    case unexpectedResponse(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "No API key configured. Go to Settings to add your API key."
        case .imageConversionFailed: return "Failed to process image."
        case .networkError: return "Network request failed. Check your connection."
        case .invalidAPIKey: return "Invalid API key. Check your key in Settings."
        case .serverError(let msg): return msg
        case .apiError(let code): return "API error (HTTP \(code))."
        case .noFormulaDetected: return "No formula detected in the selected area. Try a tighter crop."
        case .unexpectedResponse(let text): return "Unexpected response: \(text)"
        }
    }
}
