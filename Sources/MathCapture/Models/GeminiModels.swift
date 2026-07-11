import Foundation

struct GeminiRequest: Codable {
    let contents: [Content]
}

struct Content: Codable {
    let parts: [Part]
}

struct Part: Codable {
    let inlineData: InlineData?
    let text: String?

    init(inlineData: InlineData) {
        self.inlineData = inlineData
        self.text = nil
    }

    init(text: String) {
        self.text = text
        self.inlineData = nil
    }
}

struct InlineData: Codable {
    let mimeType: String
    let data: String
}

struct GeminiResponse: Codable {
    let candidates: [Candidate]?
}

struct Candidate: Codable {
    let content: Content
}
