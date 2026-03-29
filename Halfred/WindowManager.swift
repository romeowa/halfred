import AppKit
import ApplicationServices

final class WindowManager {
    enum SnapSide {
        case left, right
    }

    private var lastSnapSide: SnapSide?
    private var lastSnapIndex: Int = 0

    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "windowSnappingEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "windowSnappingEnabled") }
    }

    func snapLeft() {
        guard isEnabled else { return }
        let width = nextWidth(for: .left)
        snap(side: .left, width: width)
    }

    func snapRight() {
        guard isEnabled else { return }
        let width = nextWidth(for: .right)
        snap(side: .right, width: width)
    }

    func snapFull() {
        guard isEnabled else { return }
        guard let screen = screenForFrontmostWindow() else { return }
        let frame = screen.visibleFrame

        lastSnapSide = nil
        lastSnapIndex = 0

        setFrontmostWindowFrame(CGRect(
            x: frame.origin.x,
            y: frame.origin.y,
            width: frame.width,
            height: frame.height
        ))
    }

    func moveToNextScreen() {
        guard isEnabled else { return }
        let screens = NSScreen.screens
        guard screens.count >= 2 else { return }
        guard let currentScreen = screenForFrontmostWindow() else { return }

        // Find the next screen in the list
        let currentIndex = screens.firstIndex(of: currentScreen) ?? 0
        let nextScreen = screens[(currentIndex + 1) % screens.count]

        // Get current window frame in AX coordinates, then map relative position to next screen
        let srcVisible = currentScreen.visibleFrame
        let dstVisible = nextScreen.visibleFrame

        guard let (pos, size) = getFrontmostWindowFrame() else { return }

        // Convert AX position to AppKit coordinates
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let appKitY = primaryHeight - pos.y - size.height

        // Calculate relative position within source screen's visible frame
        let relX = (pos.x - srcVisible.origin.x) / srcVisible.width
        let relY = (appKitY - srcVisible.origin.y) / srcVisible.height
        let relW = size.width / srcVisible.width
        let relH = size.height / srcVisible.height

        // Apply relative position to destination screen
        let newW = min(relW * dstVisible.width, dstVisible.width)
        let newH = min(relH * dstVisible.height, dstVisible.height)
        let newX = dstVisible.origin.x + relX * dstVisible.width
        let newY = dstVisible.origin.y + relY * dstVisible.height

        setFrontmostWindowFrame(CGRect(x: newX, y: newY, width: newW, height: newH))
    }

    /// Returns the frontmost window's (position, size) in AX coordinates (top-left origin).
    private func getFrontmostWindowFrame() -> (CGPoint, CGSize)? {
        guard AXIsProcessTrusted(),
              let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier != Bundle.main.bundleIdentifier else { return nil }

        let appRef = AXUIElementCreateApplication(app.processIdentifier)
        var windowValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &windowValue) == .success,
              let window = windowValue else { return nil }

        var posValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window as! AXUIElement, kAXPositionAttribute as CFString, &posValue) == .success,
              AXUIElementCopyAttributeValue(window as! AXUIElement, kAXSizeAttribute as CFString, &sizeValue) == .success else { return nil }

        var pos = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posValue as! AXValue, .cgPoint, &pos)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        return (pos, size)
    }

    /// Returns snap widths: [minimum window width, 1/2 screen, 2/3 screen]
    private func snapWidths() -> [CGFloat] {
        guard let screen = screenForFrontmostWindow() else { return [] }
        let screenWidth = screen.visibleFrame.width
        let half = screenWidth * 0.5
        let twoThirds = screenWidth * (2.0 / 3.0)

        var widths: [CGFloat] = []
        if let minW = getMinWindowWidth(), minW > 0, minW < half - 1 {
            widths.append(minW)
        } else {
            widths.append(screenWidth / 3.0)
        }
        widths.append(half)
        widths.append(twoThirds)
        return widths
    }

    private func nextWidth(for side: SnapSide) -> CGFloat {
        let widths = snapWidths()
        guard !widths.isEmpty else { return screenForFrontmostWindow()?.visibleFrame.width ?? 800 }
        if lastSnapSide == side {
            lastSnapIndex = (lastSnapIndex + 1) % widths.count
        } else {
            lastSnapSide = side
            lastSnapIndex = 0
        }
        return widths[lastSnapIndex]
    }

    private func getMinWindowWidth() -> CGFloat? {
        guard AXIsProcessTrusted(),
              let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier != Bundle.main.bundleIdentifier else { return nil }

        let appRef = AXUIElementCreateApplication(app.processIdentifier)
        var windowValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &windowValue) == .success,
              let window = windowValue else { return nil }

        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window as! AXUIElement, "AXMinimumSize" as CFString, &sizeValue) == .success,
              let sizeRef = sizeValue else { return nil }

        var minSize = CGSize.zero
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &minSize)
        return minSize.width > 0 ? minSize.width : nil
    }

    private func snap(side: SnapSide, width: CGFloat) {
        guard let screen = screenForFrontmostWindow() else { return }
        let frame = screen.visibleFrame

        let x: CGFloat
        switch side {
        case .left:
            x = frame.origin.x
        case .right:
            x = frame.origin.x + frame.width - width
        }

        setFrontmostWindowFrame(CGRect(
            x: x,
            y: frame.origin.y,
            width: width,
            height: frame.height
        ))
    }

    static func promptAccessibilityOnFirstLaunch() {
        let key = "hasPromptedAccessibility"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
    }

    static var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Returns the screen where the frontmost window is located, falling back to NSScreen.main.
    private func screenForFrontmostWindow() -> NSScreen? {
        guard AXIsProcessTrusted(),
              let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier != Bundle.main.bundleIdentifier else {
            return NSScreen.main
        }

        let appRef = AXUIElementCreateApplication(app.processIdentifier)
        var windowValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &windowValue) == .success,
              let window = windowValue else {
            return NSScreen.main
        }

        var posValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window as! AXUIElement, kAXPositionAttribute as CFString, &posValue) == .success,
              AXUIElementCopyAttributeValue(window as! AXUIElement, kAXSizeAttribute as CFString, &sizeValue) == .success else {
            return NSScreen.main
        }

        var pos = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posValue as! AXValue, .cgPoint, &pos)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)

        // AX coordinates are top-left origin; find which screen contains the window center
        let centerX = pos.x + size.width / 2
        let centerY = pos.y + size.height / 2

        // Convert AX top-left Y to AppKit bottom-left Y using the primary screen height
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let appKitCenterY = primaryHeight - centerY

        let windowCenter = CGPoint(x: centerX, y: appKitCenterY)
        return NSScreen.screens.first(where: { $0.frame.contains(windowCenter) }) ?? NSScreen.main
    }

    private func setFrontmostWindowFrame(_ frame: CGRect) {
        guard AXIsProcessTrusted() else {
            NSLog("Halfred: Accessibility permission not granted")
            return
        }

        guard let app = NSWorkspace.shared.frontmostApplication else {
            NSLog("Halfred: No frontmost application")
            return
        }

        // Skip if Halfred itself is frontmost
        if app.bundleIdentifier == Bundle.main.bundleIdentifier {
            NSLog("Halfred: Skipping — Halfred is frontmost")
            return
        }

        let appRef = AXUIElementCreateApplication(app.processIdentifier)

        var windowValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &windowValue)
        guard result == .success, let window = windowValue else {
            NSLog("Halfred: Could not get focused window for \(app.localizedName ?? "unknown") (error: \(result.rawValue))")
            return
        }

        // Convert from AppKit coordinates (origin: primary screen bottom-left)
        // to AX coordinates (origin: primary screen top-left)
        // The flip must always use the primary screen height, regardless of which monitor the window is on
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 0
        let flippedY = primaryScreenHeight - frame.origin.y - frame.height

        var position = CGPoint(x: frame.origin.x, y: flippedY)
        var size = CGSize(width: frame.width, height: frame.height)

        if let posValue = AXValueCreate(.cgPoint, &position) {
            AXUIElementSetAttributeValue(window as! AXUIElement, kAXPositionAttribute as CFString, posValue)
        }
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window as! AXUIElement, kAXSizeAttribute as CFString, sizeValue)
        }

        NSLog("Halfred: Snapped \(app.localizedName ?? "unknown") to \(frame)")
    }
}
