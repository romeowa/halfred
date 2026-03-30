import AppKit
import Foundation

struct OpenCommand: CommandExecutor {
    func execute(entry: CommandEntry, argument: String?) -> Bool {
        guard let path = entry.path else { return false }

        // URL scheme (e.g. x-apple.systempreferences:...)
        if let url = URL(string: path), url.scheme != nil, !url.scheme!.isEmpty, url.scheme != "file" {
            NSWorkspace.shared.open(url)
            return true
        }

        // File path
        let expanded = NSString(string: path).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)
        NSWorkspace.shared.open(url)
        return true
    }
}
