import AppKit
import SwiftUI

final class SearchPanel {
    private var panel: NSPanel!
    private let commandRegistry: CommandRegistry
    private let appScanner: AppScanner
    private let clipboardManager: ClipboardManager

    init(commandRegistry: CommandRegistry, appScanner: AppScanner, clipboardManager: ClipboardManager) {
        self.commandRegistry = commandRegistry
        self.appScanner = appScanner
        self.clipboardManager = clipboardManager
        setupPanel()
    }

    private func setupPanel() {
        let searchView = SearchView(commandRegistry: commandRegistry, appScanner: appScanner, clipboardManager: clipboardManager) { [weak self] in
            self?.hide()
        }

        let hostingView = NSHostingView(rootView: searchView)
        hostingView.sizingOptions = [.intrinsicContentSize]

        panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 60),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.contentView = hostingView
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false


        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            self?.hide()
        }
    }

    func toggle() {
        if panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let panelWidth: CGFloat = 680
        let x = screenFrame.origin.x + (screenFrame.width - panelWidth) / 2
        let y = screenFrame.origin.y + screenFrame.height * 0.75

        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Post notification to focus the text field
        NotificationCenter.default.post(name: .halfredSearchPanelShown, object: nil)
    }

    func hide() {
        panel.orderOut(nil)
        NotificationCenter.default.post(name: .halfredSearchPanelHidden, object: nil)
    }
}

final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

extension Notification.Name {
    static let halfredSearchPanelShown = Notification.Name("halfredSearchPanelShown")
    static let halfredSearchPanelHidden = Notification.Name("halfredSearchPanelHidden")
}
