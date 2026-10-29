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

/// Every place on the shelf that accepts a drop.
enum DropTargetID: Hashable {
    case shelf
    case folder(UUID)
    case airDrop
    case shorten
    case addFolder
}

/// Holds what is on the Drop Bar and runs the action behind each target.
@MainActor
final class ShelfStore: ObservableObject {
    static let shared = ShelfStore()

    @Published private(set) var items: [ShelfItem] = []
    @Published private(set) var status: StatusMessage?
    @Published private(set) var isBusy = false
    @Published var isPinned = false
    @Published var hoveredTarget: DropTargetID?

    /// Where each drop target sits in the shelf, reported by SwiftUI.
    var targetFrames: [DropTargetID: CGRect] = [:]

    private var statusClearTask: Task<Void, Never>?

    private init() {}

    // MARK: Drop Bar contents

    func add(_ urls: [URL]) {
        for url in urls where !items.contains(where: { $0.url == url }) {
            items.append(ShelfItem(url: url))
        }
    }

    func remove(urls: [URL]) {
        items.removeAll { urls.contains($0.url) }
    }

    func clear() {
        items.removeAll()
    }

    /// After items are dragged out, drop the ones that no longer exist where
    /// they were (Finder moved them). Copied items stay on the Drop Bar.
    func dragOutEnded(_ urls: [URL]) {
        Task {
            // Finder can finish the move just after the drag session ends.
            try? await Task.sleep(nanoseconds: 800_000_000)
            let gone = urls.filter { $0.isFileURL && !FileManager.default.fileExists(atPath: $0.path) }
            remove(urls: gone)
        }
    }

    // MARK: Drops

    func accepts(_ content: DroppedContent.Result, on target: DropTargetID, fromShelf: Bool) -> Bool {
        switch target {
        case .shelf: return !fromShelf && !content.isEmpty
        case .folder: return !content.files.isEmpty
        case .airDrop: return !content.isEmpty
        case .shorten: return !content.links.isEmpty
        case .addFolder: return !content.directories.isEmpty
        }
    }

    func handleDrop(_ content: DroppedContent.Result, on target: DropTargetID) {
        Task {
            await perform(target, files: content.files, links: content.links)
            ShelfController.shared.actionDidFinish()
        }
    }

    /// A target was clicked: apply it to everything on the Drop Bar.
    /// Clicking "Shorten URL" shortens the link on the clipboard instead.
    func performOnShelf(_ target: DropTargetID) {
        Task {
            switch target {
            case .addFolder:
                ShelfController.shared.hide()
                FolderPicker.chooseFolders().forEach(AppSettings.shared.addFolder(at:))
                return
            case .shorten:
                guard let link = Self.clipboardLink() else {
                    post("Copy a link first, or drop one here", isError: true)
                    return
                }
                await shorten(link)
                return
            default:
                break
            }

            let urls = items.map(\.url)
            guard !urls.isEmpty else {
                post("Drop files here, or put them on the Drop Bar first", isError: true)
                return
            }
            await perform(target, files: urls.filter(\.isFileURL), links: urls.filter { !$0.isFileURL })
        }
    }

    private func perform(_ target: DropTargetID, files: [URL], links: [URL]) async {
        switch target {
        case .shelf:
            add(files + links)

        case .folder(let id):
            guard let folder = AppSettings.shared.folders.first(where: { $0.id == id }) else { return }
            await send(files, to: folder)

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

        case .addFolder:
            let folders = files.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            folders.forEach(AppSettings.shared.addFolder(at:))
            post(folders.count == 1 ? "Added \(folders[0].lastPathComponent)" : "Added \(folders.count) folders")
        }
    }

    private func send(_ files: [URL], to folder: FolderTarget) async {
        guard !files.isEmpty else {
            post("Only files can go into a folder", isError: true)
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            // Copying large files must not block the UI.
            let results = try await Task.detached {
                try FolderAction.perform(files: files, target: folder)
            }.value

            if folder.mode == .move {
                remove(urls: files)
            }
            let verb = folder.mode == .move ? "Moved" : "Copied"
            let noun = results.count == 1 ? "item" : "items"
            post("\(verb) \(results.count) \(noun) to \(folder.name)")
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
