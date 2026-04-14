import Foundation

struct TimerCommand: CommandExecutor {
    func execute(entry: CommandEntry, argument: String?) -> Bool {
        guard let arg = argument?.trimmingCharacters(in: .whitespaces), !arg.isEmpty else {
            NSLog("Halfred: Timer command needs argument like '10:00 name' or '3:30 점심시간'")
            return false
        }

        // Split into time (first token) and optional name (rest)
        let parts = arg.split(separator: " ", maxSplits: 1)
        let timePart = String(parts[0])
        let namePart = parts.count > 1
            ? String(parts[1]).trimmingCharacters(in: .whitespaces)
            : nil

        var totalSeconds = 0
        if timePart.contains(":") {
            let comps = timePart.split(separator: ":").map { Int($0) ?? 0 }
            switch comps.count {
            case 2: // M:SS
                totalSeconds = comps[0] * 60 + comps[1]
            case 3: // H:MM:SS
                totalSeconds = comps[0] * 3600 + comps[1] * 60 + comps[2]
            default:
                return false
            }
        } else {
            // Bare number = minutes
            let m = Int(timePart) ?? 0
            totalSeconds = m * 60
        }

        guard totalSeconds > 0 else { return false }

        DispatchQueue.main.async {
            TimerManager.shared.startNew(seconds: totalSeconds, name: namePart?.isEmpty == true ? nil : namePart)
        }
        return true
    }
}
