import SwiftUI

struct SettingsView: View {
    @ObservedObject var commandRegistry: CommandRegistry
    let windowManager: WindowManager
    @State private var editingCommand: CommandEntry?
    @State private var isAdding = false
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                SettingsTabButton(title: "General", icon: "gear", isSelected: selectedTab == 0) {
                    selectedTab = 0
                }
                SettingsTabButton(title: "Commands", icon: "command", isSelected: selectedTab == 1) {
                    selectedTab = 1
                }
                SettingsTabButton(title: "Window", icon: "macwindow", isSelected: selectedTab == 2) {
                    selectedTab = 2
                }
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .background(Theme.background)

            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)

            // Tab content
            if selectedTab == 0 {
                GeneralTab()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if selectedTab == 1 {
                CommandsTab(
                    commandRegistry: commandRegistry,
                    editingCommand: $editingCommand,
                    isAdding: $isAdding
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                WindowTab(windowManager: windowManager)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .preferredColorScheme(.dark)
        .frame(minWidth: 560, minHeight: 420)
        .sheet(isPresented: $isAdding) {
            CommandEditView(
                title: "Add Command",
                command: CommandEntry(type: "web", keyword: "", name: "", url: "", appName: nil, script: nil, path: nil),
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

// MARK: - Tab Button

struct SettingsTabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(isSelected ? Theme.accent : Theme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .contentShape(Rectangle())

                Rectangle()
                    .fill(isSelected ? Theme.accent : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - General Tab

struct GeneralTab: View {
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var accessibilityGranted = WindowManager.isAccessibilityGranted

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Startup section
                SettingsSection(title: "STARTUP") {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Launch at Login")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.textPrimary)
                            Text("Automatically start Halfred when you log in")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.textMuted)
                        }
                        Spacer()
                        Toggle("", isOn: $launchAtLogin)
                            .toggleStyle(.switch)
                            .tint(Theme.accent)
                            .onChange(of: launchAtLogin) { _, newValue in
                                LaunchAtLogin.isEnabled = newValue
                            }
                    }
                    .contentShape(Rectangle())
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
                }

                // Hotkey section
                SettingsSection(title: "HOTKEY") {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Activate Halfred")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.textPrimary)
                            Text("Show the command palette")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.textMuted)
                        }
                        Spacer()
                        HStack(spacing: 4) {
                            KeyCap(text: "⌥")
                            KeyCap(text: "Space")
                        }
                    }
                    .contentShape(Rectangle())
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
                }
                // Permissions section
                SettingsSection(title: "PERMISSIONS") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: accessibilityGranted ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(accessibilityGranted ? Theme.typeApp : .orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Accessibility Access")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Theme.textPrimary)
                                Text(accessibilityGranted
                                     ? "Accessibility permission is granted."
                                     : "Window Snapping and Shell commands need Accessibility permission to control other apps.")
                                    .font(.system(size: 11))
                                    .foregroundColor(accessibilityGranted ? Theme.textSecondary : .orange.opacity(0.9))
                            }
                        }

                        if !accessibilityGranted {
                            Button(action: {
                                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.up.forward.square")
                                        .font(.system(size: 11))
                                    Text("Open Accessibility Settings")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.accent))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .contentShape(Rectangle())
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
                    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                        accessibilityGranted = WindowManager.isAccessibilityGranted
                    }
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Window Tab

struct WindowTab: View {
    let windowManager: WindowManager
    @State private var isEnabled: Bool

    init(windowManager: WindowManager) {
        self.windowManager = windowManager
        _isEnabled = State(initialValue: windowManager.isEnabled)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsSection(title: "WINDOW SNAPPING") {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Enable Window Snapping")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.textPrimary)
                            Text("Snap windows to screen edges with keyboard shortcuts")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.textMuted)
                        }
                        Spacer()
                        Toggle("", isOn: $isEnabled)
                            .toggleStyle(.switch)
                            .tint(Theme.accent)
                            .onChange(of: isEnabled) { _, newValue in
                                windowManager.isEnabled = newValue
                            }
                    }
                    .contentShape(Rectangle())
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
                }

                SettingsSection(title: "SHORTCUTS") {
                    VStack(spacing: 1) {
                        SnapShortcutRow(
                            title: "Snap Left",
                            description: "Cycle: Min → 1/2 → 2/3",
                            keys: ["⌥", "⌘", "←"],
                            isFirst: true
                        )
                        SnapShortcutRow(
                            title: "Snap Right",
                            description: "Cycle: Min → 1/2 → 2/3",
                            keys: ["⌥", "⌘", "→"],
                            isFirst: false
                        )
                        SnapShortcutRow(
                            title: "Fullscreen",
                            description: "Expand to fill the screen",
                            keys: ["⌥", "⌘", "↑"],
                            isFirst: false
                        )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                SettingsSection(title: "HOW IT WORKS") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Press ⌥⌘← or ⌥⌘→ repeatedly to cycle through window sizes. The window snaps to the corresponding edge of the screen.")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textSecondary)

                        HStack(spacing: 16) {
                            SnapPreview(label: "Min", fraction: 0.25)
                            SnapPreview(label: "1/2", fraction: 0.5)
                            SnapPreview(label: "2/3", fraction: 0.667)
                        }
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
                }
            }
            .padding(20)
        }
    }
}

struct SnapShortcutRow: View {
    let title: String
    let description: String
    let keys: [String]
    let isFirst: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textPrimary)
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textMuted)
            }
            Spacer()
            HStack(spacing: 4) {
                ForEach(keys, id: \.self) { key in
                    KeyCap(text: key)
                }
            }
        }
        .contentShape(Rectangle())
        .padding(14)
        .background(Theme.surface)
    }
}

struct SnapPreview: View {
    let label: String
    let fraction: CGFloat

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.surfaceLight)
                    .frame(width: 60, height: 40)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Theme.accent.opacity(0.4))
                    .frame(width: 60 * fraction, height: 40)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Theme.border, lineWidth: 1)
            )
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.textMuted)
        }
    }
}

struct KeyCap: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundColor(Theme.textPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Theme.surfaceLight)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Theme.border, lineWidth: 1)
            )
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Theme.textMuted)
                .tracking(1.5)
            content
        }
    }
}

// MARK: - Commands Tab

struct CommandsTab: View {
    @ObservedObject var commandRegistry: CommandRegistry
    @Binding var editingCommand: CommandEntry?
    @Binding var isAdding: Bool

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(commandRegistry.commands) { command in
                    CommandRow(
                        command: command,
                        onEdit: { editingCommand = command },
                        onDelete: { commandRegistry.deleteCommand(keyword: command.keyword) }
                    )
                    .listRowBackground(Theme.background)
                    .listRowSeparator(.hidden)
                }
                .onMove { from, to in
                    commandRegistry.moveCommand(from: from, to: to)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.background)

            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)

            HStack {
                Button(action: { isAdding = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Theme.accent)
                        Text("Add Command")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Theme.textPrimary)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Text("\(commandRegistry.commands.count) commands")
                    .foregroundColor(Theme.textMuted)
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.background)
        }
    }
}

// MARK: - Command Row

struct CommandRow: View {
    let command: CommandEntry
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var showDeleteAlert = false
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Type icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: iconName)
                    .font(.system(size: 14))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(command.keyword)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                    Text(command.type.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Theme.textMuted)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(RoundedRectangle(cornerRadius: 3).fill(Theme.surfaceLight))
                }
                Text(command.name)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textMuted)
                    .lineLimit(1)
            }

            Spacer()

            if isHovered {
                HStack(spacing: 4) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textSecondary)
                            .frame(width: 26, height: 26)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.surfaceLight))
                    }
                    .buttonStyle(.plain)

                    Button(action: { showDeleteAlert = true }) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.accent)
                            .frame(width: 26, height: 26)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.accent.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? Theme.surface : Color.clear)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .alert("Delete Command", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { onDelete() }
        } message: {
            Text("Are you sure you want to delete \"\(command.keyword)\"?")
        }
    }

    private var iconName: String {
        switch command.type {
        case "web": return "globe"
        case "app": return "app.fill"
        case "shell": return "terminal.fill"
        case "open": return "folder.fill"
        default: return "questionmark.circle"
        }
    }

    private var iconColor: Color {
        switch command.type {
        case "web": return Theme.typeWeb
        case "app": return Theme.typeApp
        case "shell": return Theme.typeShell
        case "open": return Theme.typeOpen
        default: return Theme.textMuted
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

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
            }
            .padding(20)

            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)

            // Form
            ScrollView {
                VStack(spacing: 16) {
                    // Type picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TYPE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Theme.textMuted)
                            .tracking(1)
                        HStack(spacing: 8) {
                            TypeChip(label: "Web", icon: "globe", type: "web", selected: $command.type)
                            TypeChip(label: "App", icon: "app.fill", type: "app", selected: $command.type)
                            TypeChip(label: "Shell", icon: "terminal.fill", type: "shell", selected: $command.type)
                            TypeChip(label: "Open", icon: "folder.fill", type: "open", selected: $command.type)
                        }
                    }

                    DarkTextField(label: "KEYWORD", text: $command.keyword, placeholder: "e.g. google")
                    DarkTextField(label: "NAME", text: $command.name, placeholder: "e.g. Google Search")

                    switch command.type {
                    case "web":
                        DarkTextField(label: "URL", text: Binding(
                            get: { command.url ?? "" },
                            set: { command.url = $0.isEmpty ? nil : $0 }
                        ), placeholder: "https://google.com/search?q={query}")
                    case "app":
                        DarkTextField(label: "APP NAME", text: Binding(
                            get: { command.appName ?? "" },
                            set: { command.appName = $0.isEmpty ? nil : $0 }
                        ), placeholder: "e.g. Safari, Terminal")
                    case "shell":
                        DarkTextField(label: "SCRIPT", text: Binding(
                            get: { command.script ?? "" },
                            set: { command.script = $0.isEmpty ? nil : $0 }
                        ), placeholder: "e.g. ./runEmulator.sh")
                    case "open":
                        DarkTextField(label: "PATH", text: Binding(
                            get: { command.path ?? "" },
                            set: { command.path = $0.isEmpty ? nil : $0 }
                        ), placeholder: "e.g. ~/Projects/myapp.xcodeproj")
                    default:
                        EmptyView()
                    }
                }
                .padding(20)
            }

            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)

            // Actions
            HStack {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.surfaceLight))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(action: { onSave(command) }) {
                    Text("Save")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(command.keyword.isEmpty || command.name.isEmpty ? Theme.textMuted : Theme.accent)
                        )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .disabled(command.keyword.isEmpty || command.name.isEmpty)
            }
            .padding(16)
        }
        .frame(width: 440)
        .background(Theme.background)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Reusable Components

struct TypeChip: View {
    let label: String
    let icon: String
    let type: String
    @Binding var selected: String

    var isSelected: Bool { selected == type }

    var body: some View {
        Button(action: { selected = type }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : Theme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Theme.accent : Theme.surfaceLight)
            )
        }
        .buttonStyle(.plain)
    }
}

struct DarkTextField: View {
    let label: String
    @Binding var text: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Theme.textMuted)
                .tracking(1)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundColor(Theme.textPrimary)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Theme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Theme.border, lineWidth: 1)
                )
        }
    }
}
