import SwiftUI

struct SearchView: View {
    let commandRegistry: CommandRegistry
    let appScanner: AppScanner
    let onDismiss: () -> Void

    @State private var query: String = ""
    @State private var matchingCommands: [CommandEntry] = []
    @State private var matchingApps: [ScannedApp] = []
    @State private var selectedIndex: Int = -1

    private var totalCount: Int { matchingCommands.prefix(10).count + matchingApps.prefix(5).count }

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

            // Results list
            if !matchingCommands.isEmpty || !matchingApps.isEmpty {
                Rectangle()
                    .fill(Theme.border)
                    .frame(height: 1)

                VStack(spacing: 2) {
                    // Registered commands
                    ForEach(Array(matchingCommands.prefix(10).enumerated()), id: \.element.keyword) { index, command in
                        let isSelected = index == selectedIndex
                        commandRow(command: command, isSelected: isSelected)
                            .onHover { hovering in
                                if hovering { selectedIndex = index }
                            }
                            .onTapGesture {
                                query = command.keyword + " "
                                selectedIndex = -1
                            }
                    }

                    // Scanned apps
                    if !matchingApps.isEmpty {
                        if !matchingCommands.isEmpty {
                            HStack {
                                Text("APPS")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(Theme.textMuted)
                                Rectangle()
                                    .fill(Theme.border)
                                    .frame(height: 1)
                            }
                            .padding(.horizontal, 14)
                            .padding(.top, 4)
                        }

                        ForEach(Array(matchingApps.prefix(5).enumerated()), id: \.element.name) { appIndex, app in
                            let globalIndex = matchingCommands.prefix(10).count + appIndex
                            let isSelected = globalIndex == selectedIndex
                            appRow(app: app, isSelected: isSelected)
                                .onHover { hovering in
                                    if hovering { selectedIndex = globalIndex }
                                }
                                .onTapGesture {
                                    appScanner.launch(app)
                                    onDismiss()
                                }
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
            matchingApps = []
            selectedIndex = -1
        }
    }

    private func updateMatches(for input: String) {
        let keyword = CommandParser.parseKeyword(from: input)
        if keyword.isEmpty {
            matchingCommands = commandRegistry.allCommands()
            matchingApps = []
        } else if CommandParser.parseArgument(from: input) == nil {
            matchingCommands = commandRegistry.search(prefix: keyword)
            // Search installed apps, exclude ones already registered as commands
            let registeredAppNames = Set(
                matchingCommands.filter { $0.type == "app" }.compactMap { $0.appName?.lowercased() }
            )
            matchingApps = appScanner.search(prefix: keyword).filter {
                !registeredAppNames.contains($0.name.lowercased())
            }
        } else {
            matchingCommands = []
            matchingApps = []
        }
        selectedIndex = -1
    }

    private func moveSelection(_ delta: Int) {
        guard totalCount > 0 else { return }
        let newIndex = selectedIndex + delta
        if newIndex < 0 {
            selectedIndex = totalCount - 1
        } else if newIndex >= totalCount {
            selectedIndex = 0
        } else {
            selectedIndex = newIndex
        }
    }

    private func autocomplete() {
        let cmdCount = matchingCommands.prefix(10).count
        if selectedIndex >= 0, selectedIndex < cmdCount {
            query = matchingCommands[selectedIndex].keyword + " "
            matchingCommands = []
            matchingApps = []
            selectedIndex = -1
        } else if selectedIndex >= cmdCount, selectedIndex < totalCount {
            let app = matchingApps[selectedIndex - cmdCount]
            appScanner.launch(app)
            onDismiss()
        } else if let first = matchingCommands.first {
            query = first.keyword + " "
            matchingCommands = []
            matchingApps = []
            selectedIndex = -1
        } else if let firstApp = matchingApps.first {
            appScanner.launch(firstApp)
            onDismiss()
        }
    }

    private func executeCommand() {
        let cmdCount = matchingCommands.prefix(10).count

        // If an app result is selected, launch it
        if selectedIndex >= cmdCount, selectedIndex < totalCount {
            let app = matchingApps[selectedIndex - cmdCount]
            appScanner.launch(app)
            onDismiss()
            return
        }

        // If a command result is selected, execute it
        if selectedIndex >= 0, selectedIndex < cmdCount {
            let selected = matchingCommands[selectedIndex]
            let argument = CommandParser.parseArgument(from: query)
            if commandRegistry.execute(keyword: selected.keyword, argument: argument) {
                onDismiss()
            }
            return
        }

        // Try executing as command keyword
        let keyword = CommandParser.parseKeyword(from: query)
        let argument = CommandParser.parseArgument(from: query)
        if commandRegistry.execute(keyword: keyword, argument: argument) {
            onDismiss()
            return
        }

        // Fallback: try launching first matching app
        if let firstApp = matchingApps.first {
            appScanner.launch(firstApp)
            onDismiss()
        }
    }

    @ViewBuilder
    private func commandRow(command: CommandEntry, isSelected: Bool) -> some View {
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
    }

    @ViewBuilder
    private func appRow(app: ScannedApp, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Theme.accent.opacity(0.2) : Theme.surfaceLight)
                    .frame(width: 30, height: 30)
                Image(systemName: "app.fill")
                    .font(.system(size: 13))
                    .foregroundColor(isSelected ? Theme.accent : Theme.typeApp)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(app.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? Theme.textPrimary : Theme.textPrimary.opacity(0.9))
                Text(app.url.path)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? Theme.textSecondary : Theme.textMuted)
                    .lineLimit(1)
            }

            Spacer()

            Text("APP")
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
