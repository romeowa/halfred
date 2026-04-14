import AppKit
import Foundation

// Private CoreGraphics APIs for live cursor scale update
@_silgen_name("CGSMainConnectionID")
private func CGSMainConnectionID() -> Int32

@_silgen_name("CGSSetCursorScale")
private func CGSSetCursorScale(_ cid: Int32, _ scale: Float) -> Int32

struct CursorSizeCommand: CommandExecutor {
    func execute(entry: CommandEntry, argument: String?) -> Bool {
        guard let arg = argument?.trimmingCharacters(in: .whitespaces), !arg.isEmpty,
              let input = Double(arg) else {
            NSLog("Halfred: Cursor size requires a number argument 0-10")
            return false
        }

        // Clamp 0-10 and map linearly to macOS cursor scale 1.0-4.0
        let clamped = min(max(input, 0), 10)
        let scale = 1.0 + (clamped / 10.0) * 3.0

        // Write the preference persistently
        CFPreferencesSetValue(
            "mouseDriverCursorSize" as CFString,
            NSNumber(value: scale),
            "com.apple.universalaccess" as CFString,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
        CFPreferencesSynchronize(
            "com.apple.universalaccess" as CFString,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )

        // Apply live via private CoreGraphics API
        let conn = CGSMainConnectionID()
        let result = CGSSetCursorScale(conn, Float(scale))
        if result != 0 {
            NSLog("Halfred: CGSSetCursorScale returned \(result)")
        }

        NSLog("Halfred: Cursor size set to \(scale) (input: \(clamped))")
        return true
    }
}
