import AppKit
import SwiftUI

final class SettingsWindow {
    private var window: NSWindow?
    private let commandRegistry: CommandRegistry

    init(commandRegistry: CommandRegistry) {
        self.commandRegistry = commandRegistry
    }

    func show() {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(commandRegistry: commandRegistry)
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Halfred Settings"
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.setContentSize(NSSize(width: 600, height: 450))
        window.minSize = NSSize(width: 500, height: 350)
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }
}
