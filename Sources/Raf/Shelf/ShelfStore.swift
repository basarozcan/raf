import AppKit
import Foundation

struct ShelfItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
}

struct StatusMessage: Equatable {
    let text: String
    let isError: Bool
}

enum DropAction {
    case shelf
    case folder(FolderTarget)
    case airDrop
    case shorten
}

/// Holds what is on the shelf and runs the actions behind each drop target.
@MainActor
final class ShelfStore: ObservableObject {
    static let shared = ShelfStore()

    @Published private(set) var items: [ShelfItem] = []
    @Published private(set) var status: StatusMessage?
    @Published private(set) var isBusy = false

    private var statusClearTask: Task<Void, Never>?

    private init() {}

    // MARK: Shelf contents

    func add(_ urls: [URL]) {
        for url in urls where !items.contains(where: { $0.url == url }) {
            items.append(ShelfItem(url: url))
        }
    }

    func remove(_ item: ShelfItem) {
        items.removeAll { $0.id == item.id }
    }

    func clear() {
        items.removeAll()
    }

    // MARK: Actions

    /// Called by a drop target. Returns immediately; the work runs async.
    func handleDrop(_ providers: [NSItemProvider], action: DropAction) -> Bool {
        Task {
            let content = await DroppedContent.load(from: providers)
            await perform(action, files: content.files, links: content.links)
        }
        return true
    }

    /// Called when a drop target is clicked: applies the action to whatever
    /// is on the shelf. Clicking "Shorten URL" shortens the link on the clipboard.
    func performOnShelf(_ action: DropAction) {
        Task {
            if case .shorten = action {
                guard let link = Self.clipboardLink() else {
                    post("Copy a link first, then click Shorten URL", isError: true)
                    return
                }
                await shorten(link)
                return
            }

            let urls = items.map(\.url)
            guard !urls.isEmpty else {
                post("The shelf is empty", isError: true)
                return
            }
            await perform(action, files: urls.filter(\.isFileURL), links: urls.filter { !$0.isFileURL })
        }
    }

    private func perform(_ action: DropAction, files: [URL], links: [URL]) async {
        switch action {
        case .shelf:
            add(files + links)

        case .folder(let target):
            await sendToFolder(files, target: target)

        case .airDrop:
            let all = files + links
            guard !all.isEmpty else { return }
            if !AirDropAction.send(all) {
                post("AirDrop isn't available. Is Wi-Fi or Bluetooth off?", isError: true)
            }

        case .shorten:
            guard let link = links.first else {
                post("Drop a web link to shorten it", isError: true)
                return
            }
            await shorten(link)
        }
    }

    private func sendToFolder(_ files: [URL], target: FolderTarget) async {
        guard !files.isEmpty else {
            post("Only files can go into a folder", isError: true)
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            // Copying large files must not block the UI.
            let results = try await Task.detached {
                try FolderAction.perform(files: files, target: target)
            }.value

            if target.mode == .move {
                items.removeAll { files.contains($0.url) }
            }
            let verb = target.mode == .move ? "Moved" : "Copied"
            let noun = results.count == 1 ? "item" : "items"
            post("\(verb) \(results.count) \(noun) to \(target.name)")
        } catch {
            post(error.localizedDescription, isError: true)
        }
    }

    private func shorten(_ link: URL) async {
        isBusy = true
        defer { isBusy = false }

        do {
            let short = try await URLShortener.shorten(link, config: AppSettings.shared.shortenerConfig())
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(short.absoluteString, forType: .string)
            post("Copied \(short.absoluteString)")
            Notifier.post(title: "Short link copied", body: short.absoluteString)
        } catch {
            post(error.localizedDescription, isError: true)
        }
    }

    // MARK: Helpers

    private func post(_ text: String, isError: Bool = false) {
        status = StatusMessage(text: text, isError: isError)
        statusClearTask?.cancel()
        statusClearTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            status = nil
        }
    }

    private static func clipboardLink() -> URL? {
        guard let text = NSPasteboard.general.string(forType: .string) else { return nil }
        return DroppedContent.webURL(from: text)
    }
}
