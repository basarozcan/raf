import Foundation
import UniformTypeIdentifiers

/// Turns whatever was dropped (files, browser links, plain text) into URLs.
enum DroppedContent {
    struct Result {
        var files: [URL] = []
        var links: [URL] = []
    }

    static let types: [UTType] = [.fileURL, .url, .plainText]

    static func load(from providers: [NSItemProvider]) async -> Result {
        var result = Result()

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
                || provider.canLoadObject(ofClass: URL.self) {
                guard let url = await loadURL(from: provider) else { continue }
                if url.isFileURL {
                    result.files.append(url)
                } else if let web = webURL(from: url.absoluteString) {
                    result.links.append(web)
                }
            } else if provider.canLoadObject(ofClass: String.self) {
                if let text = await loadString(from: provider), let web = webURL(from: text) {
                    result.links.append(web)
                }
            }
        }

        return result
    }

    /// Returns a URL only for http(s) links, so stray text is ignored.
    static func webURL(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil
        else { return nil }
        return url
    }

    private static func loadURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                continuation.resume(returning: url)
            }
        }
    }

    private static func loadString(from provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: String.self) { text, _ in
                continuation.resume(returning: text)
            }
        }
    }
}
