import AppKit
import SwiftUI

struct SearchTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = "Type a command..."
    var onSubmit: () -> Void
    var onTab: () -> Void
    var onEscape: () -> Void
    var onArrowUp: () -> Void
    var onArrowDown: () -> Void
    var onCmd1: (() -> Void)?
    var onCmd2: (() -> Void)?

    func makeNSView(context: Context) -> NSTextField {
        let textField = TabAwareTextField()
        textField.delegate = context.coordinator
        textField.onTab = onTab
        textField.onEscape = onEscape
        textField.onCmd1 = onCmd1
        textField.onCmd2 = onCmd2
        textField.font = .systemFont(ofSize: 20, weight: .light)
        textField.textColor = .white
        textField.isBordered = false
        textField.backgroundColor = .clear
        textField.focusRingType = .none
        textField.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: NSColor(white: 0.40, alpha: 1.0),
                .font: NSFont.systemFont(ofSize: 20, weight: .light),
            ]
        )
        textField.cell?.lineBreakMode = .byTruncatingTail
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        // Update placeholder
        nsView.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: NSColor(white: 0.40, alpha: 1.0),
                .font: NSFont.systemFont(ofSize: 20, weight: .light),
            ]
        )
        // Update closures
        if let tabField = nsView as? TabAwareTextField {
            tabField.onTab = onTab
            tabField.onEscape = onEscape
            tabField.onCmd1 = onCmd1
            tabField.onCmd2 = onCmd2
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: SearchTextField

        init(_ parent: SearchTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                parent.onTab()
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onEscape()
                return true
            }
            if commandSelector == #selector(NSResponder.moveUp(_:)) {
                parent.onArrowUp()
                return true
            }
            if commandSelector == #selector(NSResponder.moveDown(_:)) {
                parent.onArrowDown()
                return true
            }
            return false
        }
    }
}

final class TabAwareTextField: NSTextField {
    var onTab: (() -> Void)?
    var onEscape: (() -> Void)?
    var onCmd1: (() -> Void)?
    var onCmd2: (() -> Void)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            if event.charactersIgnoringModifiers == "1" {
                onCmd1?()
                return true
            }
            if event.charactersIgnoringModifiers == "2" {
                onCmd2?()
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}
