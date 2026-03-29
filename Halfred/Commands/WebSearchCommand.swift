import AppKit
import Foundation

struct WebSearchCommand: CommandExecutor {
    func execute(entry: CommandEntry, argument: String?) -> Bool {
        guard let urlTemplate = entry.url else { return false }
        let query = argument ?? ""
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = urlTemplate.replacingOccurrences(of: "{query}", with: encodedQuery)

        guard let url = URL(string: urlString) else { return false }
        NSWorkspace.shared.open(url)
        return true
    }
}
