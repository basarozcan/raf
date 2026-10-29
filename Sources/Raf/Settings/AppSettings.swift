import Foundation

struct FolderTarget: Identifiable, Hashable, Codable {
    enum Mode: String, Codable, CaseIterable {
        case copy
        case move
    }

    var id = UUID()
    var name: String
    var path: String
    var mode: Mode = .copy

    var url: URL { URL(fileURLWithPath: path, isDirectory: true) }
}

/// User preferences. Plain settings live in UserDefaults; API keys live in
/// the Keychain, one entry per shortener provider.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Key {
        static let folders = "folders"
        static let showOnDrag = "showOnDrag"
        static let shortener = "shortener"
        static let shortenerBaseURL = "shortenerBaseURL"
    }

    private let defaults = UserDefaults.standard

    @Published var folders: [FolderTarget] {
        didSet { saveFolders() }
    }

    @Published var showOnDrag: Bool {
        didSet { defaults.set(showOnDrag, forKey: Key.showOnDrag) }
    }

    @Published var shortener: ShortenerProvider {
        didSet { defaults.set(shortener.rawValue, forKey: Key.shortener) }
    }

    @Published var shortenerBaseURL: String {
        didSet { defaults.set(shortenerBaseURL, forKey: Key.shortenerBaseURL) }
    }

    private init() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Key.folders),
           let saved = try? JSONDecoder().decode([FolderTarget].self, from: data) {
            folders = saved
        } else {
            folders = []
        }
        showOnDrag = defaults.object(forKey: Key.showOnDrag) as? Bool ?? false
        shortener = defaults.string(forKey: Key.shortener).flatMap(ShortenerProvider.init(rawValue:)) ?? .tinyURL
        shortenerBaseURL = defaults.string(forKey: Key.shortenerBaseURL) ?? ""
    }

    func addFolder(at url: URL) {
        guard !folders.contains(where: { $0.path == url.path }) else { return }
        folders.append(FolderTarget(name: url.lastPathComponent, path: url.path))
    }

    func apiKey(for provider: ShortenerProvider) -> String {
        Keychain.read(account: provider.rawValue) ?? ""
    }

    func setAPIKey(_ key: String, for provider: ShortenerProvider) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            Keychain.delete(account: provider.rawValue)
        } else {
            Keychain.save(trimmed, account: provider.rawValue)
        }
    }

    func shortenerConfig() -> ShortenerConfig {
        ShortenerConfig(provider: shortener, apiKey: apiKey(for: shortener), baseURL: shortenerBaseURL)
    }

    private func saveFolders() {
        if let data = try? JSONEncoder().encode(folders) {
            defaults.set(data, forKey: Key.folders)
        }
    }
}
