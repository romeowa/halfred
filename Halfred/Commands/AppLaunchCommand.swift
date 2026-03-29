import AppKit
import Foundation

struct AppLaunchCommand: CommandExecutor {
    func execute(entry: CommandEntry, argument: String?) -> Bool {
        guard let appName = entry.appName else { return false }

        let appURL: URL?
        // Check if appName is a direct path to a .app bundle
        if appName.hasSuffix(".app"), FileManager.default.fileExists(atPath: appName) {
            appURL = URL(fileURLWithPath: appName)
        } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: appName) {
            appURL = url
        } else {
            // Try finding by name in /Applications
            let paths = [
                "/Applications/\(appName).app",
                "/System/Applications/\(appName).app",
                "/System/Applications/Utilities/\(appName).app",
            ]
            appURL = paths.compactMap { path in
                let url = URL(fileURLWithPath: path)
                return FileManager.default.fileExists(atPath: path) ? url : nil
            }.first
        }

        guard let url = appURL else {
            NSLog("Halfred: Could not find app: \(appName)")
            return false
        }

        // For path-based apps, use /usr/bin/open which reliably handles
        // all bundle types including iOS/iPad wrapped bundles.
        if appName.contains("/") {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-a", url.path]
            do {
                try process.run()
            } catch {
                NSLog("Halfred: Failed to open \(appName): \(error)")
            }
        } else {
            NSWorkspace.shared.openApplication(at: url, configuration: .init()) { _, error in
                if let error = error {
                    NSLog("Halfred: Failed to launch \(appName): \(error)")
                }
            }
        }
        return true
    }
}
