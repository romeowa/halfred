import AppKit
import SwiftUI

final class SettingsWindow {
    private var window: NSWindow?
    private let commandRegistry: CommandRegistry
    private let windowManager: WindowManager
    private let appScanner: AppScanner

    init(commandRegistry: CommandRegistry, windowManager: WindowManager, appScanner: AppScanner) {
        self.commandRegistry = commandRegistry
        self.windowManager = windowManager
        self.appScanner = appScanner
    }

    func show() {
        if let window = window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Recreate window to ensure fresh SwiftUI rendering
        let settingsView = SettingsView(commandRegistry: commandRegistry, windowManager: windowManager, appScanner: appScanner)
        let hostingController = NSHostingController(rootView: settingsView)

        let window = EscClosableWindow(contentViewController: hostingController)
        window.title = "Halfred Settings"
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.setContentSize(NSSize(width: 600, height: 480))
        window.minSize = NSSize(width: 560, height: 420)
        window.center()
        window.backgroundColor = .halfredBackground
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.level = .normal

        self.window = window
    }
}

final class EscClosableWindow: NSWindow {
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            close()
        } else {
            super.keyDown(with: event)
        }
    }
}
