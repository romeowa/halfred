import Foundation

enum CommandParser {
    static func parseKeyword(from input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: " ", maxSplits: 1)
        return parts.first.map(String.init) ?? ""
    }

    static func parseArgument(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: " ", maxSplits: 1)
        guard parts.count > 1 else { return nil }
        return String(parts[1]).trimmingCharacters(in: .whitespaces)
    }
}
