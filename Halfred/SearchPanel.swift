import AppKit
import SwiftUI

final class SearchPanel {
    private var panel: NSPanel!
    private let commandRegistry: CommandRegistry

    init(commandRegistry: CommandRegistry) {
        self.commandRegistry = commandRegistry
        setupPanel()
    }

    private func setupPanel() {
        let searchView = SearchView(commandRegistry: commandRegistry) { [weak self] in
            self?.hide()
        }

        let hostingView = NSHostingView(rootView: searchView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 680, height: 54)

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 54),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.contentView = hostingView
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false

        // ESC key closes the panel
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
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

extension Notification.Name {
    static let halfredSearchPanelShown = Notification.Name("halfredSearchPanelShown")
    static let halfredSearchPanelHidden = Notification.Name("halfredSearchPanelHidden")
}
