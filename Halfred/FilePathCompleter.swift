import Foundation

struct PathItem: Identifiable {
    let id = UUID()
    let name: String
    let fullPath: String
    let isDirectory: Bool
}

enum FilePathCompleter {
    private static let home = FileManager.default.homeDirectoryForCurrentUser.path

    /// Resolves the partial path to an absolute path.
    /// `./` maps to home directory (since GUI apps have CWD at `/`).
    static func resolve(_ partial: String) -> String {
        if partial.hasPrefix("~/") {
            return (partial as NSString).expandingTildeInPath
        } else if partial.hasPrefix("/") {
            return partial
        } else {
            // `./` or plain relative — resolve from home directory
            let stripped = partial.hasPrefix("./") ? String(partial.dropFirst(2)) : partial
            return (home as NSString).appendingPathComponent(stripped)
        }
    }

    /// Returns file/folder suggestions for a partial path input.
    static func complete(partial: String) -> [PathItem] {
        let resolved = resolve(partial)
        let expanded: String
        let searchPrefix: String

        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: resolved, isDirectory: &isDir), isDir.boolValue {
            expanded = resolved
            searchPrefix = ""
        } else {
            expanded = (resolved as NSString).deletingLastPathComponent
            searchPrefix = (resolved as NSString).lastPathComponent.lowercased()
        }

        guard FileManager.default.fileExists(atPath: expanded) else { return [] }

        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: expanded)
            let filtered = contents
                .filter { !$0.hasPrefix(".") }
                .filter { searchPrefix.isEmpty || $0.lowercased().hasPrefix(searchPrefix) }
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

            return filtered.prefix(20).map { name in
                let full = (expanded as NSString).appendingPathComponent(name)
                var isDir: ObjCBool = false
                FileManager.default.fileExists(atPath: full, isDirectory: &isDir)
                return PathItem(name: name, fullPath: full, isDirectory: isDir.boolValue)
            }
        } catch {
            NSLog("Halfred PathComplete: error listing directory: \(error)")
            return []
        }
    }

    /// Builds the display path for autocomplete insertion.
    /// Preserves the user's prefix style (`./`, `~/`, `/`).
    static func completionText(for item: PathItem, originalPartial: String) -> String {
        let result: String

        if originalPartial.hasPrefix("~/") {
            if item.fullPath.hasPrefix(home) {
                result = "~" + item.fullPath.dropFirst(home.count)
            } else {
                result = item.fullPath
            }
        } else if originalPartial.hasPrefix("/") {
            result = item.fullPath
        } else {
            // `./` or relative — show as ~/...
            if item.fullPath.hasPrefix(home) {
                result = "~" + item.fullPath.dropFirst(home.count)
            } else {
                result = item.fullPath
            }
        }

        return item.isDirectory ? result + "/" : result
    }
}
