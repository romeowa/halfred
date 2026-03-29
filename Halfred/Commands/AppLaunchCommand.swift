import AppKit
import Foundation

struct AppLaunchCommand: CommandExecutor {
    func execute(entry: CommandEntry, argument: String?) -> Bool {
        guard let appName = entry.appName else { return false }

        let appURL: URL?
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: appName) {
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

        NSWorkspace.shared.openApplication(at: url, configuration: .init()) { _, error in
            if let error = error {
                NSLog("Halfred: Failed to launch \(appName): \(error)")
            }
        }
        return true
    }
}
