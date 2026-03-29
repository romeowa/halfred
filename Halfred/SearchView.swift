import SwiftUI

struct SearchView: View {
    let commandRegistry: CommandRegistry
    let onDismiss: () -> Void

    @State private var query: String = ""
    @State private var matchingCommands: [CommandEntry] = []
    @State private var selectedIndex: Int = -1

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)

                SearchTextField(
                    text: $query,
                    onSubmit: { executeCommand() },
                    onTab: { autocomplete() },
                    onEscape: { onDismiss() },
                    onArrowUp: { moveSelection(-1) },
                    onArrowDown: { moveSelection(1) }
                )
                .onChange(of: query) { _, newValue in
                    updateMatches(for: newValue)
                }

                if !query.isEmpty {
                    Button(action: { query = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if !matchingCommands.isEmpty {
                Divider()
                VStack(spacing: 0) {
                    ForEach(Array(matchingCommands.enumerated()), id: \.element.keyword) { index, command in
                        HStack {
                            Image(systemName: iconName(for: command.type))
                                .foregroundColor(index == selectedIndex ? .white : .secondary)
                                .frame(width: 24)
                            Text(command.keyword)
                                .fontWeight(.medium)
                                .foregroundColor(index == selectedIndex ? .white : .primary)
                            Text("- \(command.name)")
                                .foregroundColor(index == selectedIndex ? .white.opacity(0.8) : .secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(
                            index == selectedIndex
                                ? RoundedRectangle(cornerRadius: 6).fill(Color.accentColor)
                                : nil
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            query = command.keyword + " "
                            selectedIndex = -1
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThickMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .onReceive(NotificationCenter.default.publisher(for: .halfredSearchPanelShown)) { _ in
            query = ""
            matchingCommands = []
            selectedIndex = -1
        }
    }

    private func updateMatches(for input: String) {
        let keyword = CommandParser.parseKeyword(from: input)
        if keyword.isEmpty {
            matchingCommands = commandRegistry.allCommands()
        } else if CommandParser.parseArgument(from: input) == nil {
            matchingCommands = commandRegistry.search(prefix: keyword)
        } else {
            matchingCommands = []
        }
        selectedIndex = -1
    }

    private func moveSelection(_ delta: Int) {
        guard !matchingCommands.isEmpty else { return }
        let newIndex = selectedIndex + delta
        if newIndex < 0 {
            selectedIndex = matchingCommands.count - 1
        } else if newIndex >= matchingCommands.count {
            selectedIndex = 0
        } else {
            selectedIndex = newIndex
        }
    }

    private func autocomplete() {
        let target: CommandEntry?
        if selectedIndex >= 0, selectedIndex < matchingCommands.count {
            target = matchingCommands[selectedIndex]
        } else {
            target = matchingCommands.first
        }
        if let command = target {
            query = command.keyword + " "
            matchingCommands = []
            selectedIndex = -1
        }
    }

    private func executeCommand() {
        // If an item is selected from the list, use that command
        if selectedIndex >= 0, selectedIndex < matchingCommands.count {
            let selected = matchingCommands[selectedIndex]
            let argument = CommandParser.parseArgument(from: query)
            if commandRegistry.execute(keyword: selected.keyword, argument: argument) {
                onDismiss()
            }
            return
        }

        let keyword = CommandParser.parseKeyword(from: query)
        let argument = CommandParser.parseArgument(from: query)

        if commandRegistry.execute(keyword: keyword, argument: argument) {
            onDismiss()
        }
    }

    private func iconName(for type: String) -> String {
        switch type {
        case "web": return "globe"
        case "app": return "app"
        case "shell": return "terminal"
        case "open": return "folder"
        default: return "questionmark.circle"
        }
    }
}
