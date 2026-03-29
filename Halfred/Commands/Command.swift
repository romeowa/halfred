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
}

struct CommandsFile: Codable {
    let commands: [CommandEntry]
}

protocol CommandExecutor {
    func execute(entry: CommandEntry, argument: String?) -> Bool
}
