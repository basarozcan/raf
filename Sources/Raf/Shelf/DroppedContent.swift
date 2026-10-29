import AppKit

/// Reads what is being dragged (files, browser links, plain-text links)
/// straight from the drag pasteboard.
///
/// Files are always read as file URLs first, whatever their type, so a
/// Markdown or other text file is treated as a file and not as its text.
enum DroppedContent {
    struct Result {
        var files: [URL] = []
        var links: [URL] = []

        var all: [URL] { files + links }
        var isEmpty: Bool { files.isEmpty && links.isEmpty }
        var directories: [URL] {
            files.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
        }
    }

    static let pasteboardTypes: [NSPasteboard.PasteboardType] = [.fileURL, .URL, .string]

    static func read(from pasteboard: NSPasteboard) -> Result {
        var result = Result()

        let fileOptions: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        if let files = pasteboard.readObjects(forClasses: [NSURL.self], options: fileOptions) as? [URL] {
            result.files = files
        }
        guard result.files.isEmpty else { return result }

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            result.links = urls.compactMap { webURL(from: $0.absoluteString) }
        }
        if result.links.isEmpty, let text = pasteboard.string(forType: .string), let web = webURL(from: text) {
            result.links = [web]
        }
        return result
    }

    /// Picks an operation the drag source allows. Raf does the actual copy
    /// or move itself, this only controls the cursor and what the source
    /// does afterwards.
    static func operation(for info: NSDraggingInfo) -> NSDragOperation {
        let mask = info.draggingSourceOperationMask
        for candidate: NSDragOperation in [.copy, .generic, .move, .link] where mask.contains(candidate) {
            return candidate
        }
        return []
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
}
