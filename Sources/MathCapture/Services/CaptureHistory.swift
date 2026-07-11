import Foundation
import AppKit

struct CaptureEntry: Codable, Identifiable {
    let id: String
    let timestamp: Date
    let content: String
    let format: String
    let provider: String
    let model: String
    let imageFileName: String?

    var imageURL: URL? {
        guard let name = imageFileName else { return nil }
        return CaptureHistory.imagesDir?.appendingPathComponent(name)
    }

    var formatLabel: String {
        format == "LaTeX" ? "LaTeX" : "MathML"
    }
}

@MainActor
final class CaptureHistory: ObservableObject {
    static let shared = CaptureHistory()

    @Published private(set) var entries: [CaptureEntry] = []

    private static let maxEntries = 50
    nonisolated private static let historyFile = "history.json"

    nonisolated private static var storageDir: URL? {
        try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("com.maarten.mathcapture")
    }

    nonisolated static var imagesDir: URL? {
        storageDir?.appendingPathComponent("images")
    }

    nonisolated private static var historyURL: URL? {
        storageDir?.appendingPathComponent(historyFile)
    }

    private init() {
        load()
    }

    func addEntry(content: String, format: String, provider: String, model: String, image: CGImage?) {
        let id = UUID().uuidString
        var imageFileName: String?

        if let image {
            imageFileName = saveImage(image, id: id)
        }

        let entry = CaptureEntry(
            id: id,
            timestamp: Date(),
            content: content,
            format: format,
            provider: provider,
            model: model,
            imageFileName: imageFileName
        )

        entries.insert(entry, at: 0)

        if entries.count > Self.maxEntries {
            let removed = entries.dropFirst(Self.maxEntries)
            for entry in removed {
                deleteImage(for: entry)
            }
            entries = Array(entries.prefix(Self.maxEntries))
        }

        save()
    }

    func clearAll() {
        for entry in entries {
            deleteImage(for: entry)
        }
        entries.removeAll()
        save()
    }

    private func saveImage(_ image: CGImage, id: String) -> String? {
        guard let dir = Self.imagesDir else { return nil }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let fileName = "\(id).jpg"
        let url = dir.appendingPathComponent(fileName)

        let bitmapRep = NSBitmapImageRep(cgImage: image)
        guard let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.6]) else {
            return nil
        }

        try? jpegData.write(to: url)
        return fileName
    }

    private func deleteImage(for entry: CaptureEntry) {
        guard let url = entry.imageURL else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private func save() {
        guard let url = Self.historyURL else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(entries) {
            try? data.write(to: url)
        }
    }

    private func load() {
        guard let url = Self.historyURL, let data = try? Data(contentsOf: url) else { return }
        entries = (try? JSONDecoder().decode([CaptureEntry].self, from: data)) ?? []
    }
}
