import SwiftUI

struct SettingsView: View {
    @ObservedObject var commandRegistry: CommandRegistry
    @State private var editingCommand: CommandEntry?
    @State private var isAdding = false

    var body: some View {
        VStack(spacing: 0) {
            // Command list
            List {
                ForEach(commandRegistry.commands) { command in
                    CommandRow(command: command, onEdit: {
                        editingCommand = command
                    }, onDelete: {
                        commandRegistry.deleteCommand(keyword: command.keyword)
                    })
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))

            Divider()

            // Bottom bar
            HStack {
                Button(action: { isAdding = true }) {
                    Label("Add Command", systemImage: "plus")
                }

                Spacer()

                Text("\(commandRegistry.commands.count) commands")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(12)
        }
        .frame(minWidth: 500, minHeight: 350)
        .sheet(isPresented: $isAdding) {
            CommandEditView(
                title: "Add Command",
                command: CommandEntry(type: "web", keyword: "", name: "", url: "", appName: nil, script: nil),
                onSave: { newCommand in
                    commandRegistry.addCommand(newCommand)
                    isAdding = false
                },
                onCancel: { isAdding = false }
            )
        }
        .sheet(item: $editingCommand) { command in
            CommandEditView(
                title: "Edit Command",
                command: command,
                onSave: { updated in
                    commandRegistry.updateCommand(oldKeyword: command.keyword, with: updated)
                    editingCommand = nil
                },
                onCancel: { editingCommand = nil }
            )
        }
    }
}

// MARK: - Command Row

struct CommandRow: View {
    let command: CommandEntry
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .foregroundColor(iconColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(command.keyword)
                        .fontWeight(.semibold)
                        .font(.body)
                    Text("(\(command.type))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(command.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 2)
    }

    private var iconName: String {
        switch command.type {
        case "web": return "globe"
        case "app": return "app"
        case "shell": return "terminal"
        case "open": return "folder"
        default: return "questionmark.circle"
        }
    }

    private var iconColor: Color {
        switch command.type {
        case "web": return .blue
        case "app": return .green
        case "shell": return .orange
        case "open": return .purple
        default: return .secondary
        }
    }

    private var detail: String {
        switch command.type {
        case "web": return command.url ?? ""
        case "app": return command.appName ?? ""
        case "shell": return command.script ?? ""
        case "open": return command.path ?? ""
        default: return ""
        }
    }
}

// MARK: - Command Edit Form

struct CommandEditView: View {
    let title: String
    @State var command: CommandEntry
    let onSave: (CommandEntry) -> Void
    let onCancel: () -> Void

    private let types = ["web", "app", "shell"]

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.headline)
                .padding(.top, 16)

            Form {
                Picker("Type", selection: $command.type) {
                    Text("Web Search").tag("web")
                    Text("App Launch").tag("app")
                    Text("Shell Script").tag("shell")
                    Text("Open File/Folder").tag("open")
                }

                TextField("Keyword", text: $command.keyword)
                    .help("The shortcut you type to trigger this command")

                TextField("Name", text: $command.name)
                    .help("Display name shown in results")

                switch command.type {
                case "web":
                    TextField("URL", text: Binding(
                        get: { command.url ?? "" },
                        set: { command.url = $0.isEmpty ? nil : $0 }
                    ))
                    .help("Use {query} as placeholder for search term")

                case "app":
                    TextField("App Name", text: Binding(
                        get: { command.appName ?? "" },
                        set: { command.appName = $0.isEmpty ? nil : $0 }
                    ))
                    .help("Application name (e.g. Safari, Terminal)")

                case "shell":
                    TextField("Script", text: Binding(
                        get: { command.script ?? "" },
                        set: { command.script = $0.isEmpty ? nil : $0 }
                    ))
                    .help("Shell command or script path to run in Terminal")

                case "open":
                    TextField("Path", text: Binding(
                        get: { command.path ?? "" },
                        set: { command.path = $0.isEmpty ? nil : $0 }
                    ))
                    .help("File or folder path (e.g. ~/Projects/myapp.xcodeproj)")

                default:
                    EmptyView()
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal, 8)

            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    onSave(command)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(command.keyword.isEmpty || command.name.isEmpty)
            }
            .padding(16)
        }
        .frame(width: 420)
    }
}
