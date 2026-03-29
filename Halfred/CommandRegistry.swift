import Foundation

final class CommandRegistry: ObservableObject {
    @Published private(set) var commands: [CommandEntry] = []
    private let executors: [String: CommandExecutor] = [
        "web": WebSearchCommand(),
        "app": AppLaunchCommand(),
        "shell": ShellCommand(),
        "open": OpenCommand(),
    ]

    private var userConfigURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".halfred")
            .appendingPathComponent("commands.json")
    }

    func loadCommands() {
        commands = []

        // Load from bundled commands.json
        if let bundledURL = Bundle.main.url(forResource: "commands", withExtension: "json") {
            loadFromFile(url: bundledURL)
        }

        // Load from user config (~/.halfred/commands.json), overrides bundled
        if FileManager.default.fileExists(atPath: userConfigURL.path) {
            loadFromFile(url: userConfigURL)
        }

        NSLog("Halfred: Loaded \(commands.count) commands")
    }

    private func loadFromFile(url: URL) {
        guard let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(CommandsFile.self, from: data) else {
            NSLog("Halfred: Failed to load commands from \(url.path)")
            return
        }
        for command in file.commands {
            commands.removeAll { $0.keyword == command.keyword }
            commands.append(command)
        }
    }

    // MARK: - CRUD

    func addCommand(_ command: CommandEntry) {
        commands.removeAll { $0.keyword == command.keyword }
        commands.append(command)
        saveUserCommands()
    }

    func updateCommand(oldKeyword: String, with command: CommandEntry) {
        commands.removeAll { $0.keyword == oldKeyword }
        commands.removeAll { $0.keyword == command.keyword }
        commands.append(command)
        saveUserCommands()
    }

    func deleteCommand(keyword: String) {
        commands.removeAll { $0.keyword == keyword }
        saveUserCommands()
    }

    func saveUserCommands() {
        let dir = userConfigURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let file = CommandsFile(commands: commands)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(file) else {
            NSLog("Halfred: Failed to encode commands")
            return
        }
        do {
            try data.write(to: userConfigURL)
            NSLog("Halfred: Saved \(commands.count) commands to \(userConfigURL.path)")
        } catch {
            NSLog("Halfred: Failed to save commands: \(error)")
        }
    }

    // MARK: - Query

    func allCommands() -> [CommandEntry] {
        commands
    }

    func search(prefix: String) -> [CommandEntry] {
        let lower = prefix.lowercased()
        return commands.filter { $0.keyword.lowercased().hasPrefix(lower) }
    }

    @discardableResult
    func execute(keyword: String, argument: String?) -> Bool {
        guard let entry = commands.first(where: { $0.keyword.lowercased() == keyword.lowercased() }),
              let executor = executors[entry.type] else {
            return false
        }
        return executor.execute(entry: entry, argument: argument)
    }
}
