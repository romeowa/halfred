import AppKit

struct ScannedApp {
    let name: String
    let url: URL
}

final class AppScanner {
    private var apps: [ScannedApp] = []

    init() {
        scan()
    }

    func scan() {
        var results: [String: ScannedApp] = [:]

        let searchDirs = [
            "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
            NSHomeDirectory() + "/Applications",
        ]

        let fm = FileManager.default
        for dir in searchDirs {
            guard let contents = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for item in contents where item.hasSuffix(".app") {
                let appName = String(item.dropLast(4)) // remove ".app"
                let url = URL(fileURLWithPath: dir).appendingPathComponent(item)

                // First found wins (user /Applications > system)
                if results[appName.lowercased()] == nil {
                    results[appName.lowercased()] = ScannedApp(name: appName, url: url)
                }
            }
        }

        apps = results.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func search(prefix: String) -> [ScannedApp] {
        guard !prefix.isEmpty else { return [] }
        let lower = prefix.lowercased()
        return apps.filter { app in
            let name = app.name.lowercased()
            // Match full name prefix or any word prefix
            // e.g. "one" matches "Microsoft OneNote"
            if name.hasPrefix(lower) { return true }
            let words = name.split(whereSeparator: { $0 == " " || $0 == "-" })
            return words.dropFirst().contains { $0.hasPrefix(lower) }
        }
    }

    func launch(_ app: ScannedApp) {
        NSWorkspace.shared.openApplication(at: app.url, configuration: .init()) { _, error in
            if let error = error {
                NSLog("Failed to launch \(app.name): \(error)")
            }
        }
    }
}
