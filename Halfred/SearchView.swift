import Carbon
import SwiftUI

enum SearchMode: String {
    case clipboard
    case commands
    case runningApps
    case translate
}

struct SearchView: View {
    let commandRegistry: CommandRegistry
    let appScanner: AppScanner
    let clipboardManager: ClipboardManager
    let onDismiss: () -> Void

    @State private var query: String = ""
    @AppStorage("lastSearchMode") private var savedMode: String = SearchMode.commands.rawValue
    @State private var mode: SearchMode = .commands
    @State private var matchingCommands: [CommandEntry] = []
    @State private var matchingApps: [ScannedApp] = []
    @State private var selectedIndex: Int = -1
    @State private var copiedHint: Bool = false
    @State private var translatedText: String = ""
    @State private var isTranslating: Bool = false
    @State private var translationDirection: String = ""
    @State private var translateTask: Task<Void, Never>?
    @State private var runningApps: [NSRunningApplication] = []
    @State private var selectedApps: Set<pid_t> = []
    @State private var pathSuggestions: [PathItem] = []

    private var filteredRunningApps: [NSRunningApplication] {
        let q = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return runningApps }
        return runningApps.filter { app in
            app.localizedName?.lowercased().contains(q) == true
        }
    }

    private var totalCount: Int {
        switch mode {
        case .commands:
            if !pathSuggestions.isEmpty { return pathSuggestions.count }
            return matchingCommands.prefix(10).count + matchingApps.prefix(5).count
        case .clipboard:
            return clipboardManager.filteredItems(query: query).count
        case .runningApps:
            return filteredRunningApps.count
        case .translate:
            return translatedText.isEmpty ? 0 : 1
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            if mode == .translate {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "textformat")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Theme.accent)
                        .padding(.top, 4)

                    MultilineSearchTextField(
                        text: $query,
                        placeholder: "Type to translate... (⇧Enter for newline)",
                        onSubmit: { executeAction() },
                        onEscape: { onDismiss() },
                        onCmd1: { switchMode(.commands) },
                        onCmd2: { switchMode(.clipboard) },
                        onCmd3: { switchMode(.runningApps) },
                        onCmd4: { switchMode(.translate) }
                    )
                    .frame(minHeight: 60, maxHeight: 120)
                    .onChange(of: query) { _, _ in
                        translatedText = ""
                        translationDirection = ""
                    }

                    if !query.isEmpty {
                        Button(action: { query = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Theme.textMuted)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            } else {
                HStack(spacing: 12) {
                    Image(systemName: mode == .clipboard ? "clipboard" : mode == .runningApps ? "macwindow.on.rectangle" : "magnifyingglass")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Theme.accent)

                    SearchTextField(
                        text: $query,
                        placeholder: mode == .clipboard ? "Search clipboard..." : mode == .runningApps ? "Search running apps..." : "Type a command...",
                        onSubmit: { executeAction() },
                        onTab: { handleTab() },
                        onEscape: { onDismiss() },
                        onArrowUp: { moveSelection(-1) },
                        onArrowDown: { moveSelection(1) },
                        onArrowLeft: { moveSelectionHorizontal(-1) },
                        onArrowRight: { moveSelectionHorizontal(1) },
                        onCmd1: { switchMode(.commands) },
                        onCmd2: { switchMode(.clipboard) },
                        onCmd3: { switchMode(.runningApps) },
                        onCmd4: { switchMode(.translate) }
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
            }

            // Mode toggle (⌘1 Commands, ⌘2 Clipboard)
            HStack(spacing: 0) {
                modeButton(title: "Commands", icon: "command", shortcut: "⌘1", isSelected: mode == .commands) {
                    switchMode(.commands)
                }
                modeButton(title: "Clipboard", icon: "clipboard", shortcut: "⌘2", isSelected: mode == .clipboard) {
                    switchMode(.clipboard)
                }
                modeButton(title: "Running", icon: "macwindow.on.rectangle", shortcut: "⌘3", isSelected: mode == .runningApps) {
                    switchMode(.runningApps)
                }
                modeButton(title: "Translate", icon: "textformat", shortcut: "⌘4", isSelected: mode == .translate) {
                    switchMode(.translate)
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
                if !pathSuggestions.isEmpty {
                    Rectangle()
                        .fill(Theme.border)
                        .frame(height: 1)

                    VStack(spacing: 2) {
                        ForEach(Array(pathSuggestions.enumerated()), id: \.element.id) { index, item in
                            let isSelected = index == selectedIndex
                            pathRow(item: item, isSelected: isSelected)
                                .onHover { hovering in
                                    if hovering { selectedIndex = index }
                                }
                                .onTapGesture {
                                    selectPathItem(item)
                                }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
                } else if !matchingCommands.isEmpty || !matchingApps.isEmpty {
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

            case .runningApps:
                Rectangle()
                    .fill(Theme.border)
                    .frame(height: 1)

                runningAppsContent()

            case .translate:
                Rectangle()
                    .fill(Theme.border)
                    .frame(height: 1)

                translateContent()
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
            let restored = SearchMode(rawValue: savedMode) ?? .commands
            mode = restored
            copiedHint = false
            appScanner.scan()
            matchingCommands = restored == .commands ? commandRegistry.allCommands() : []
            matchingApps = []
            pathSuggestions = []
            runningApps = []
            selectedIndex = -1
            translatedText = ""
            translationDirection = ""
            isTranslating = false
            translateTask?.cancel()
            if restored == .runningApps { refreshRunningApps() }
            switchToEnglishInput()
        }
    }

    // MARK: - Input Source

    private func switchToEnglishInput() {
        guard let sources = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else { return }
        for source in sources {
            guard let categoryRef = TISGetInputSourceProperty(source, kTISPropertyInputSourceCategory),
                  let category = Unmanaged<CFString>.fromOpaque(categoryRef).takeUnretainedValue() as String? as String?,
                  category == kTISCategoryKeyboardInputSource as String else { continue }

            guard let selectableRef = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsSelectCapable) else { continue }
            let selectable = Unmanaged<CFBoolean>.fromOpaque(selectableRef).takeUnretainedValue()
            guard CFBooleanGetValue(selectable) else { continue }

            guard let idRef = TISGetInputSourceProperty(source, kTISPropertyInputSourceID),
                  let sourceID = Unmanaged<CFString>.fromOpaque(idRef).takeUnretainedValue() as String? as String? else { continue }

            if sourceID.contains("ABC") || sourceID.contains("US") || sourceID.contains("com.apple.keylayout.ABC") {
                TISSelectInputSource(source)
                return
            }
        }
    }

    // MARK: - Translation

    private func triggerTranslation(for text: String) {
        translateTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isTranslating = true
        translateTask = Task {

            let result = await TranslationService.shared.translate(text: trimmed)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                if let result = result {
                    translatedText = result.translated
                    let srcLabel = result.sourceLang == "ko" ? "Korean" : languageName(result.sourceLang)
                    let tgtLabel = result.targetLang == "ko" ? "Korean" : "English"
                    translationDirection = "\(srcLabel) → \(tgtLabel)"
                } else {
                    translatedText = ""
                    translationDirection = ""
                }
                isTranslating = false
            }
        }
    }

    private func languageName(_ code: String) -> String {
        switch code {
        case "ko": return "Korean"
        case "en": return "English"
        case "ja": return "Japanese"
        case "zh-CN", "zh-TW", "zh": return "Chinese"
        default: return code.uppercased()
        }
    }

    @ViewBuilder
    private func translateContent() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if isTranslating {
                HStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                        .padding(.vertical, 16)
                    Spacer()
                }
            } else if !translatedText.isEmpty {
                // Direction label
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.accent)
                    Text(translationDirection)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.textMuted)
                    Spacer()
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(translatedText, forType: .string)
                        showCopiedHint()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 10))
                            Text("Copy")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(Theme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Theme.surfaceLight))
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 6)

                // Translated text
                Text(translatedText)
                    .font(.system(size: 15))
                    .foregroundColor(Theme.textPrimary)
                    .textSelection(.enabled)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 14)
            } else {
                HStack {
                    Spacer()
                    Text(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                         ? "Type text and press Enter to translate"
                         : "Press Enter to translate")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textMuted)
                        .padding(.vertical, 16)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Running Apps

    private func toggleAppSelection(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        if selectedApps.contains(pid) {
            selectedApps.remove(pid)
        } else {
            selectedApps.insert(pid)
        }
    }

    private func selectAllApps() {
        let apps = filteredRunningApps
        if selectedApps.count == apps.count {
            selectedApps.removeAll()
        } else {
            selectedApps = Set(apps.map { $0.processIdentifier })
        }
    }

    private func quitSelectedApps() {
        let appsToQuit = runningApps.filter { selectedApps.contains($0.processIdentifier) }
        for app in appsToQuit {
            app.terminate()
        }
        selectedApps.removeAll()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            refreshRunningApps()
        }
    }

    private func activateRunningApp(_ app: NSRunningApplication) {
        onDismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            app.unhide()
            if let bundleURL = app.bundleURL {
                let config = NSWorkspace.OpenConfiguration()
                config.activates = true
                NSWorkspace.shared.openApplication(at: bundleURL, configuration: config)
            } else {
                app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            }
        }
    }

    private func refreshRunningApps() {
        runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.localizedName != nil }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    private let runningAppsColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    @ViewBuilder
    private func runningAppsContent() -> some View {
        let apps = filteredRunningApps
        if apps.isEmpty {
            HStack {
                Spacer()
                Text("No running apps found")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textMuted)
                    .padding(.vertical, 16)
                Spacer()
            }
        } else {
            LazyVGrid(columns: runningAppsColumns, spacing: 8) {
                ForEach(Array(apps.enumerated()), id: \.element.processIdentifier) { index, app in
                    let isSelected = index == selectedIndex
                    let isChecked = selectedApps.contains(app.processIdentifier)
                    runningAppCell(app: app, isSelected: isSelected, isChecked: isChecked)
                        .onHover { hovering in
                            if hovering { selectedIndex = index }
                        }
                        .onTapGesture {
                            toggleAppSelection(app)
                        }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            // Bottom action bar
            if !selectedApps.isEmpty {
                Rectangle()
                    .fill(Theme.border)
                    .frame(height: 1)

                HStack(spacing: 10) {
                    Button(action: { selectAllApps() }) {
                        Text(selectedApps.count == filteredRunningApps.count ? "Deselect All" : "Select All")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.surfaceLight))
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }

                    Spacer()

                    Button(action: { quitSelectedApps() }) {
                        HStack(spacing: 5) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                            Text("Close (\(selectedApps.count))")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.accent))
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
        }
    }

    @ViewBuilder
    private func runningAppCell(app: NSRunningApplication, isSelected: Bool, isChecked: Bool) -> some View {
        VStack(spacing: 6) {
            ZStack {
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 36, height: 36)
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 24))
                        .foregroundColor(isSelected ? Theme.accent : Theme.typeApp)
                }

                if isChecked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Theme.accent)
                        .background(Circle().fill(Color.white).frame(width: 12, height: 12))
                        .offset(x: 16, y: -16)
                } else if app.isActive {
                    Circle()
                        .fill(Theme.typeApp)
                        .frame(width: 8, height: 8)
                        .offset(x: 16, y: -16)
                }
            }

            Text(app.localizedName ?? "Unknown")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isSelected ? Theme.textPrimary : Theme.textPrimary.opacity(0.85))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isChecked ? Theme.accent.opacity(0.15) : isSelected ? Theme.accent.opacity(0.12) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isChecked ? Theme.accent.opacity(0.5) : isSelected ? Theme.accent.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
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
        savedMode = newMode.rawValue
        selectedIndex = -1
        selectedApps.removeAll()
        if newMode == .commands {
            updateMatches(for: query)
        } else if newMode == .runningApps {
            refreshRunningApps()
        } else if newMode == .translate {
            triggerTranslation(for: query)
        }
        // Re-focus input field after mode switch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NotificationCenter.default.post(name: .halfredFocusInput, object: nil)
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

        case .runningApps:
            if !selectedApps.isEmpty {
                quitSelectedApps()
            } else {
                let apps = filteredRunningApps
                let index = selectedIndex >= 0 ? selectedIndex : 0
                guard index < apps.count else { return }
                activateRunningApp(apps[index])
            }

        case .translate:
            if !translatedText.isEmpty {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(translatedText, forType: .string)
                showCopiedHint()
            } else {
                triggerTranslation(for: query)
            }
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
            pathSuggestions = []
        } else if let argument = CommandParser.parseArgument(from: input), isPathPrefix(argument) {
            matchingCommands = []
            matchingApps = []
            pathSuggestions = FilePathCompleter.complete(partial: argument)
        } else if CommandParser.parseArgument(from: input) == nil {
            matchingCommands = commandRegistry.search(prefix: keyword)
            let registeredAppNames = Set(
                matchingCommands.filter { $0.type == "app" }.compactMap { $0.appName?.lowercased() }
            )
            matchingApps = appScanner.search(prefix: keyword).filter {
                !registeredAppNames.contains($0.name.lowercased())
            }
            pathSuggestions = []
        } else {
            matchingCommands = []
            matchingApps = []
            pathSuggestions = []
        }
        selectedIndex = -1
    }

    private func isPathPrefix(_ text: String) -> Bool {
        text.hasPrefix("./") || text.hasPrefix("~/") || text.hasPrefix("/")
    }

    private func moveSelection(_ delta: Int) {
        guard totalCount > 0 else { return }
        let step = (mode == .runningApps) ? delta * runningAppsColumns.count : delta
        var newIndex = selectedIndex + step
        if newIndex < 0 { newIndex = totalCount - 1 }
        else if newIndex >= totalCount { newIndex = 0 }
        selectedIndex = newIndex
    }

    @discardableResult
    private func moveSelectionHorizontal(_ delta: Int) -> Bool {
        guard mode == .runningApps, totalCount > 0 else { return false }
        var newIndex = selectedIndex + delta
        if newIndex < 0 { newIndex = totalCount - 1 }
        else if newIndex >= totalCount { newIndex = 0 }
        selectedIndex = newIndex
        return true
    }

    private func autocomplete() {
        // Path completion mode
        if !pathSuggestions.isEmpty {
            let index = selectedIndex >= 0 ? selectedIndex : 0
            guard index < pathSuggestions.count else { return }
            selectPathItem(pathSuggestions[index])
            return
        }

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
        // Path mode: Enter opens in Finder
        if !pathSuggestions.isEmpty {
            if selectedIndex >= 0, selectedIndex < pathSuggestions.count {
                // Open the selected suggestion
                let item = pathSuggestions[selectedIndex]
                let url = URL(fileURLWithPath: item.fullPath)
                NSWorkspace.shared.open(url)
            } else if let argument = CommandParser.parseArgument(from: query) {
                // No selection — open the currently typed path
                let resolved = FilePathCompleter.resolve(argument)
                let url = URL(fileURLWithPath: resolved)
                NSWorkspace.shared.open(url)
            }
            onDismiss()
            return
        }
        // Also handle direct path argument without suggestions visible
        if let argument = CommandParser.parseArgument(from: query), isPathPrefix(argument) {
            let resolved = FilePathCompleter.resolve(argument)
            let url = URL(fileURLWithPath: resolved)
            NSWorkspace.shared.open(url)
            onDismiss()
            return
        }

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

    // MARK: - Path Completion

    private func selectPathItem(_ item: PathItem) {
        let keyword = CommandParser.parseKeyword(from: query)
        let argument = CommandParser.parseArgument(from: query) ?? ""
        let completed = FilePathCompleter.completionText(for: item, originalPartial: argument)
        query = keyword + " " + completed
        if !item.isDirectory {
            // File selected — ready to execute
            selectedIndex = -1
        }
    }

    @ViewBuilder
    private func pathRow(item: PathItem, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Theme.accent.opacity(0.2) : Theme.surfaceLight)
                    .frame(width: 30, height: 30)
                Image(systemName: item.isDirectory ? "folder.fill" : fileIcon(for: item.name))
                    .font(.system(size: 13))
                    .foregroundColor(isSelected ? Theme.accent : item.isDirectory ? Theme.typeOpen : Theme.textMuted)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(item.name + (item.isDirectory ? "/" : ""))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? Theme.textPrimary : Theme.textPrimary.opacity(0.9))
                Text(item.fullPath)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? Theme.textSecondary : Theme.textMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Text(item.isDirectory ? "DIR" : "FILE")
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

    private func fileIcon(for name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.fill"
        case "png", "jpg", "jpeg", "gif", "webp", "heic": return "photo.fill"
        case "mp4", "mov", "avi", "mkv": return "film.fill"
        case "mp3", "wav", "aac", "flac": return "music.note"
        case "zip", "tar", "gz", "rar": return "archivebox.fill"
        case "swift", "py", "js", "ts", "rs", "go", "java": return "chevron.left.forwardslash.chevron.right"
        case "txt", "md", "json", "yml", "yaml", "xml": return "doc.text.fill"
        case "app": return "app.fill"
        default: return "doc.fill"
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
