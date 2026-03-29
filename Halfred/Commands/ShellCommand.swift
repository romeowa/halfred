import AppKit
import Foundation

struct ShellCommand: CommandExecutor {
    func execute(entry: CommandEntry, argument: String?) -> Bool {
        guard let script = entry.script else { return false }

        // Use osascript via Process to avoid NSAppleScript sandboxing issues
        let appleScript = """
        tell application "Terminal"
            activate
            do script "\(escapeForAppleScript(script))"
        end tell
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", appleScript]

        let errorPipe = Pipe()
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus != 0 {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorMsg = String(data: errorData, encoding: .utf8) ?? "unknown"
                NSLog("Halfred: osascript error: \(errorMsg)")
                return false
            }
            return true
        } catch {
            NSLog("Halfred: Failed to run osascript: \(error)")
            return false
        }
    }

    private func escapeForAppleScript(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
