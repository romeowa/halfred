import Foundation

struct CommandEntry: Codable, Identifiable {
    var id: String { keyword }
    var type: String
    var keyword: String
    var name: String
    var url: String?
    var appName: String?
    var script: String?
    var path: String?

    /// Individual keywords parsed from the comma-separated `keyword` field.
    var keywords: [String] {
        keyword.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// The first keyword, used as the primary display name.
    var primaryKeyword: String {
        keywords.first ?? keyword
    }
}

struct CommandsFile: Codable {
    let commands: [CommandEntry]
}

protocol CommandExecutor {
    func execute(entry: CommandEntry, argument: String?) -> Bool
}
