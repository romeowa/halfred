import SwiftUI

enum Theme {
    // Netflix-inspired colors
    static let background = Color(red: 0.08, green: 0.08, blue: 0.08)       // #141414
    static let surface = Color(red: 0.12, green: 0.12, blue: 0.12)          // #1F1F1F
    static let surfaceLight = Color(red: 0.18, green: 0.18, blue: 0.18)     // #2D2D2D
    static let accent = Color(red: 0.90, green: 0.04, blue: 0.08)           // #E50914
    static let accentHover = Color(red: 0.75, green: 0.03, blue: 0.06)      // #BF070F
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.65)                            // #A6A6A6
    static let textMuted = Color(white: 0.40)                                // #666666
    static let border = Color(white: 0.20)                                   // #333333
    static let searchBar = Color(red: 0.15, green: 0.15, blue: 0.15)        // #262626

    // Type icon colors
    static let typeWeb = Color(red: 0.35, green: 0.65, blue: 1.0)
    static let typeApp = Color(red: 0.30, green: 0.85, blue: 0.45)
    static let typeShell = Color(red: 1.0, green: 0.60, blue: 0.25)
    static let typeOpen = Color(red: 0.70, green: 0.50, blue: 1.0)
}

// Netflix-style NSColor for AppKit
extension NSColor {
    static let halfredBackground = NSColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1.0)
}
