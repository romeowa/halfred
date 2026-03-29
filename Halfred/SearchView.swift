import SwiftUI

enum SearchMode {
    case clipboard
    case commands
}

struct SearchView: View {
    let commandRegistry: CommandRegistry
    let appScanner: AppScanner
    let clipboardManager: ClipboardManager
    let onDismiss: () -> Void

    @State private var query: String = ""
    @State private var mode: SearchMode = .commands
    @State private var matchingCommands: [CommandEntry] = []
    @State private var matchingApps: [ScannedApp] = []
    @State private var selectedIndex: Int = -1
    @State private var copiedHint: Bool = false

    private var totalCount: Int {
        switch mode {
        case .commands:
            return matchingCommands.prefix(10).count + matchingApps.prefix(5).count
        case .clipboard:
            return clipboardManager.filteredItems(query: query).count
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 12) {
                Image(systemName: mode == .clipboard ? "clipboard" : "magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Theme.accent)

                SearchTextField(
                    text: $query,
                    placeholder: mode == .clipboard ? "Search clipboard..." : "Type a command...",
                    onSubmit: { executeAction() },
                    onTab: { handleTab() },
                    onEscape: { onDismiss() },
                    onArrowUp: { moveSelection(-1) },
                    onArrowDown: { moveSelection(1) },
                    onCmd1: { switchMode(.commands) },
                    onCmd2: { switchMode(.clipboard) }
                )
                .onChange(of: query) { _, newValue in
                    if mode == .commands {
                        updateMatches(for: newValue)
                    }
                    selectedIndex = -1
                }

                if !query.isEmpty {
                    Button(action: { query = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Theme.textMuted)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)

            // Mode toggle (⌘1 Commands, ⌘2 Clipboard)
            HStack(spacing: 0) {
                modeButton(title: "Commands", icon: "command", shortcut: "⌘1", isSelected: mode == .commands) {
                    switchMode(.commands)
                }
                modeButton(title: "Clipboard", icon: "clipboard", shortcut: "⌘2", isSelected: mode == .clipboard) {
                    switchMode(.clipboard)
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 8)

            // Content
            switch mode {
            case .clipboard:
                Rectangle()
                    .fill(Theme.border)
                    .frame(height: 1)

                ClipboardHistoryView(
                        clipboardManager: clipboardManager,
                        query: query,
                        selectedIndex: selectedIndex,
                        onPaste: { item in
                            clipboardManager.copyToClipboard(item)
                            showCopiedHint()
                        },
                        onCopyText: { _ in
                            showCopiedHint()
                        },
                        onRemove: { item in
                            clipboardManager.removeItem(item)
                        }
                    )

            case .commands:
                if !matchingCommands.isEmpty || !matchingApps.isEmpty {
                    Rectangle()
                        .fill(Theme.border)
                        .frame(height: 1)

                    VStack(spacing: 2) {
                        ForEach(Array(matchingCommands.prefix(10).enumerated()), id: \.element.keyword) { index, command in
                            let isSelected = index == selectedIndex
                            commandRow(command: command, isSelected: isSelected)
                                .onHover { hovering in
                                    if hovering { selectedIndex = index }
                                }
                                .onTapGesture {
                                    query = matchingKeyword(for: command) + " "
                                    selectedIndex = -1
                                }
                        }

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
        }
        .background(Theme.background)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.border, lineWidth: 1)
        )
        .shadow(color: Theme.accent.opacity(0.08), radius: 20, y: 8)
        .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
        .overlay(
            Group {
                if copiedHint {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                        Text("Copied!")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Theme.typeApp)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: copiedHint)
        )
        .onReceive(NotificationCenter.default.publisher(for: .halfredSearchPanelShown)) { _ in
            query = ""
            mode = .commands
            copiedHint = false
            matchingCommands = commandRegistry.allCommands()
            matchingApps = []
            selectedIndex = -1
        }
    }

    // MARK: - Mode Button

    @ViewBuilder
    private func modeButton(title: String, icon: String, shortcut: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Text(shortcut)
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? Theme.accent.opacity(0.6) : Theme.textMuted.opacity(0.6))
            }
            .foregroundColor(isSelected ? Theme.accent : Theme.textMuted)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Theme.accent.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Theme.accent.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }

    private func switchMode(_ newMode: SearchMode) {
        mode = newMode
        selectedIndex = -1
        if newMode == .commands {
            updateMatches(for: query)
        }
    }

    // MARK: - Actions

    private func handleTab() {
        if mode == .commands {
            autocomplete()
        }
    }

    private func executeAction() {
        switch mode {
        case .clipboard:
            let items = clipboardManager.filteredItems(query: query)
            let index = selectedIndex >= 0 ? selectedIndex : 0
            guard index < items.count else { return }
            clipboardManager.copyToClipboard(items[index])
            showCopiedHint()

        case .commands:
            executeCommand()
        }
    }

    private func showCopiedHint() {
        copiedHint = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            copiedHint = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                onDismiss()
            }
        }
    }

    private func updateMatches(for input: String) {
        let keyword = CommandParser.parseKeyword(from: input)
        if keyword.isEmpty {
            matchingCommands = commandRegistry.allCommands()
            matchingApps = []
        } else if CommandParser.parseArgument(from: input) == nil {
            matchingCommands = commandRegistry.search(prefix: keyword)
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
            query = matchingKeyword(for: matchingCommands[selectedIndex]) + " "
            matchingCommands = []
            matchingApps = []
            selectedIndex = -1
        } else if selectedIndex >= cmdCount, selectedIndex < totalCount {
            let app = matchingApps[selectedIndex - cmdCount]
            appScanner.launch(app)
            onDismiss()
        } else if let first = matchingCommands.first {
            query = matchingKeyword(for: first) + " "
            matchingCommands = []
            matchingApps = []
            selectedIndex = -1
        } else if let firstApp = matchingApps.first {
            appScanner.launch(firstApp)
            onDismiss()
        }
    }

    /// Returns the keyword from the entry that best matches the current query input.
    private func matchingKeyword(for entry: CommandEntry) -> String {
        let input = CommandParser.parseKeyword(from: query).lowercased()
        return entry.keywords.first { $0.lowercased().hasPrefix(input) } ?? entry.primaryKeyword
    }

    private func executeCommand() {
        let cmdCount = matchingCommands.prefix(10).count

        if selectedIndex >= cmdCount, selectedIndex < totalCount {
            let app = matchingApps[selectedIndex - cmdCount]
            appScanner.launch(app)
            onDismiss()
            return
        }

        if selectedIndex >= 0, selectedIndex < cmdCount {
            let selected = matchingCommands[selectedIndex]
            let argument = CommandParser.parseArgument(from: query)
            if commandRegistry.execute(keyword: selected.primaryKeyword, argument: argument) {
                onDismiss()
            }
            return
        }

        // If only one result total, execute it directly
        if totalCount == 1 {
            if let onlyCommand = matchingCommands.first {
                let argument = CommandParser.parseArgument(from: query)
                if commandRegistry.execute(keyword: onlyCommand.primaryKeyword, argument: argument) {
                    onDismiss()
                }
            } else if let onlyApp = matchingApps.first {
                appScanner.launch(onlyApp)
                onDismiss()
            }
            return
        }

        let keyword = CommandParser.parseKeyword(from: query)
        let argument = CommandParser.parseArgument(from: query)
        if commandRegistry.execute(keyword: keyword, argument: argument) {
            onDismiss()
            return
        }

        if let firstApp = matchingApps.first {
            appScanner.launch(firstApp)
            onDismiss()
        }
    }

    // MARK: - Row Views

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
                Text(matchingKeyword(for: command))
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
