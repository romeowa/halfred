import AppKit
import Foundation

struct ShellCommand: CommandExecutor {
    func execute(entry: CommandEntry, argument: String?) -> Bool {
        guard let script = entry.script else { return false }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")

        // If the script is AppleScript (starts with "tell"), run it directly.
        // Otherwise, run it as a shell command inside Terminal.
        if script.trimmingCharacters(in: .whitespaces).hasPrefix("tell ") {
            process.arguments = ["-e", script]
        } else {
            let appleScript = """
            tell application "Terminal"
                do script "\(escapeForAppleScript(script))"
                activate
            end tell
            """
            process.arguments = ["-e", appleScript]
        }

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
