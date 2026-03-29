import SwiftUI

struct SearchView: View {
    let commandRegistry: CommandRegistry
    let onDismiss: () -> Void

    @State private var query: String = ""
    @State private var matchingCommands: [CommandEntry] = []
    @State private var selectedIndex: Int = -1

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Theme.accent)

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
                            .foregroundColor(Theme.textMuted)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        if hovering {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)

            // Command list
            if !matchingCommands.isEmpty {
                Rectangle()
                    .fill(Theme.border)
                    .frame(height: 1)

                VStack(spacing: 2) {
                    ForEach(Array(matchingCommands.prefix(10).enumerated()), id: \.element.keyword) { index, command in
                            let isSelected = index == selectedIndex
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(isSelected ? Theme.accent.opacity(0.2) : Theme.surfaceLight)
                                        .frame(width: 30, height: 30)
                                    Image(systemName: iconName(for: command.type))
                                        .font(.system(size: 13))
                                        .foregroundColor(isSelected ? Theme.accent : iconColor(for: command.type))
                                }

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(command.keyword)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(isSelected ? Theme.textPrimary : Theme.textPrimary.opacity(0.9))
                                    Text(command.name)
                                        .font(.system(size: 11))
                                        .foregroundColor(isSelected ? Theme.textSecondary : Theme.textMuted)
                                }

                                Spacer()

                                Text(command.type.uppercased())
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(isSelected ? Theme.accent : Theme.textMuted)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(isSelected ? Theme.accent.opacity(0.15) : Theme.surfaceLight)
                                    )
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isSelected ? Theme.accent.opacity(0.12) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isSelected ? Theme.accent.opacity(0.3) : Color.clear, lineWidth: 1)
                            )
                            .contentShape(Rectangle())
                            .onHover { hovering in
                                if hovering {
                                    selectedIndex = index
                                }
                            }
                            .onTapGesture {
                                query = command.keyword + " "
                                selectedIndex = -1
                            }
                        }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
            }
        }
        .background(Theme.background)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.border, lineWidth: 1)
        )
        .shadow(color: Theme.accent.opacity(0.08), radius: 20, y: 8)
        .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
        .onReceive(NotificationCenter.default.publisher(for: .halfredSearchPanelShown)) { _ in
            query = ""
            matchingCommands = commandRegistry.allCommands()
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
        case "app": return "app.fill"
        case "shell": return "terminal.fill"
        case "open": return "folder.fill"
        default: return "questionmark.circle"
        }
    }

    private func iconColor(for type: String) -> Color {
        switch type {
        case "web": return Theme.typeWeb
        case "app": return Theme.typeApp
        case "shell": return Theme.typeShell
        case "open": return Theme.typeOpen
        default: return Theme.textMuted
        }
    }
}
