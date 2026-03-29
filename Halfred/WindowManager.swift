import AppKit
import ApplicationServices

final class WindowManager {
    enum SnapSide {
        case left, right
    }

    enum SnapRatio: CGFloat, CaseIterable {
        case half = 0.5
        case oneThird = 0.333333
        case twoThirds = 0.666667
    }

    private var lastSnapSide: SnapSide?
    private var lastSnapRatioIndex: Int = 0
    private let ratios: [SnapRatio] = [.half, .oneThird, .twoThirds]

    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "windowSnappingEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "windowSnappingEnabled") }
    }

    func snapLeft() {
        guard isEnabled else { return }
        let availableRatios = supportedRatios()
        let ratio = nextRatio(for: .left, from: availableRatios)
        snap(side: .left, ratio: ratio)
    }

    func snapRight() {
        guard isEnabled else { return }
        let availableRatios = supportedRatios()
        let ratio = nextRatio(for: .right, from: availableRatios)
        snap(side: .right, ratio: ratio)
    }

    func snapFull() {
        guard isEnabled else { return }
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame

        lastSnapSide = nil
        lastSnapRatioIndex = 0

        setFrontmostWindowFrame(CGRect(
            x: frame.origin.x,
            y: frame.origin.y,
            width: frame.width,
            height: frame.height
        ))
    }

    private func nextRatio(for side: SnapSide, from available: [SnapRatio]) -> SnapRatio {
        guard !available.isEmpty else { return .half }
        if lastSnapSide == side {
            lastSnapRatioIndex = (lastSnapRatioIndex + 1) % available.count
        } else {
            lastSnapSide = side
            lastSnapRatioIndex = 0
        }
        return available[lastSnapRatioIndex]
    }

    private func supportedRatios() -> [SnapRatio] {
        guard let screen = NSScreen.main else { return ratios }
        let screenWidth = screen.visibleFrame.width
        let minWidth = getMinWindowWidth()

        guard let minWidth = minWidth, minWidth > 0 else { return ratios }

        return ratios.filter { ratio in
            screenWidth * ratio.rawValue >= minWidth
        }
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

    private func snap(side: SnapSide, ratio: SnapRatio) {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let width = frame.width * ratio.rawValue

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

        // Convert from AppKit coordinates (origin bottom-left) to screen coordinates (origin top-left)
        guard let screen = NSScreen.main else { return }
        let screenHeight = screen.frame.height
        let flippedY = screenHeight - frame.origin.y - frame.height

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
