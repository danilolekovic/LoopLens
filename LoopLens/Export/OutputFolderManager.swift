import AppKit
import Darwin

struct OutputFolderManager {
    private let defaults: UserDefaults
    private let bookmarkKey = "outputFolderBookmark"

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    var defaultURL: URL {
        accountHomeDirectory
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("LoopLens", isDirectory: true)
    }

    private var accountHomeDirectory: URL {
        guard let passwordEntry = getpwuid(getuid()) else {
            return FileManager.default.homeDirectoryForCurrentUser
        }
        return URL(
            fileURLWithPath: String(cString: passwordEntry.pointee.pw_dir),
            isDirectory: true
        )
    }

    func savedURL() -> URL? {
        guard let data = defaults.data(forKey: bookmarkKey) else { return nil }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }

        if isStale {
            try? save(url)
        }
        return url
    }

    func save(_ url: URL) throws {
        let data = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        defaults.set(data, forKey: bookmarkKey)
    }

    func reset() {
        defaults.removeObject(forKey: bookmarkKey)
    }

    func availableURL(for baseName: String, in folder: URL) -> URL {
        let fileManager = FileManager.default
        var candidate = folder.appendingPathComponent(baseName).appendingPathExtension("gif")
        var suffix = 2

        while fileManager.fileExists(atPath: candidate.path) {
            candidate = folder
                .appendingPathComponent("\(baseName) \(suffix)")
                .appendingPathExtension("gif")
            suffix += 1
        }
        return candidate
    }
}
