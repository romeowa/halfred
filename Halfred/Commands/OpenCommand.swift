import AppKit
import Foundation

struct OpenCommand: CommandExecutor {
    func execute(entry: CommandEntry, argument: String?) -> Bool {
        guard let path = entry.path else { return false }

        let expanded = NSString(string: path).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)

        NSWorkspace.shared.open(url)
        return true
    }
}
