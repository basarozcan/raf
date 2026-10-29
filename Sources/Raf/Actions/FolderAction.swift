import Foundation

enum FolderAction {
    /// Copies or moves files into the target folder. Never overwrites:
    /// a clash becomes "name 2.ext", "name 3.ext", and so on.
    static func perform(files: [URL], target: FolderTarget) throws -> [URL] {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: target.url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw FolderActionError.missingFolder(target.name)
        }

        var results: [URL] = []
        for file in files {
            let destination = uniqueDestination(for: file, in: target.url)
            switch target.mode {
            case .copy:
                try fileManager.copyItem(at: file, to: destination)
            case .move:
                try fileManager.moveItem(at: file, to: destination)
            }
            results.append(destination)
        }
        return results
    }

    private static func uniqueDestination(for file: URL, in folder: URL) -> URL {
        let fileManager = FileManager.default
        let base = file.deletingPathExtension().lastPathComponent
        let ext = file.pathExtension

        var candidate = folder.appendingPathComponent(file.lastPathComponent)
        var counter = 2
        while fileManager.fileExists(atPath: candidate.path) {
            let name = ext.isEmpty ? "\(base) \(counter)" : "\(base) \(counter).\(ext)"
            candidate = folder.appendingPathComponent(name)
            counter += 1
        }
        return candidate
    }
}

enum FolderActionError: LocalizedError {
    case missingFolder(String)

    var errorDescription: String? {
        switch self {
        case .missingFolder(let name):
            return "The folder \"\(name)\" no longer exists. Update it in Settings."
        }
    }
}
