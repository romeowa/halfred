import AppKit
import Carbon
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var searchPanel: SearchPanel!
    private var settingsWindow: SettingsWindow!
    private let hotkeyManager = HotkeyManager()
    private let commandRegistry = CommandRegistry()
    private let windowManager = WindowManager()
    private let appScanner = AppScanner()
    private let clipboardManager = ClipboardManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupCommandRegistry()
        setupStatusBar()
        setupSearchPanel()
        setupSettingsWindow()
        setupHotkey()
        clipboardManager.startMonitoring()
        WindowManager.promptAccessibilityOnFirstLaunch()
    }

    private func setupCommandRegistry() {
        commandRegistry.loadCommands()
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "command", accessibilityDescription: "Halfred")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Halfred", action: #selector(toggleSearchPanel), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Reload Commands", action: #selector(reloadCommands), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Halfred", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func setupSearchPanel() {
        searchPanel = SearchPanel(commandRegistry: commandRegistry, appScanner: appScanner, clipboardManager: clipboardManager)
    }

    private func setupHotkey() {
        hotkeyManager.register(id: 1, keyCode: 49, modifiers: UInt32(optionKey)) { [weak self] in
            self?.toggleSearchPanel()
        }
        // ⌘, for Settings
        hotkeyManager.register(id: 2, keyCode: 43, modifiers: UInt32(cmdKey)) { [weak self] in
            self?.searchPanel.hide()
            self?.openSettings()
        }
        // ⌥⌘← Snap left
        hotkeyManager.register(id: 10, keyCode: 123, modifiers: UInt32(optionKey | cmdKey)) { [weak self] in
            self?.windowManager.snapLeft()
        }
        // ⌥⌘→ Snap right
        hotkeyManager.register(id: 11, keyCode: 124, modifiers: UInt32(optionKey | cmdKey)) { [weak self] in
            self?.windowManager.snapRight()
        }
        // ⌥⌘↑ Snap full
        hotkeyManager.register(id: 12, keyCode: 126, modifiers: UInt32(optionKey | cmdKey)) { [weak self] in
            self?.windowManager.snapFull()
        }
    }

    private func setupSettingsWindow() {
        settingsWindow = SettingsWindow(commandRegistry: commandRegistry, windowManager: windowManager)
    }

    @objc private func toggleSearchPanel() {
        searchPanel.toggle()
    }

    @objc private func openSettings() {
        settingsWindow.show()
    }

    @objc private func reloadCommands() {
        commandRegistry.loadCommands()
    }
}
