import AppKit
import SwiftUI

struct SearchTextField: NSViewRepresentable {
    @Binding var text: String
    var onSubmit: () -> Void
    var onTab: () -> Void
    var onEscape: () -> Void
    var onArrowUp: () -> Void
    var onArrowDown: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let textField = TabAwareTextField()
        textField.delegate = context.coordinator
        textField.onTab = onTab
        textField.onEscape = onEscape
        textField.font = .systemFont(ofSize: 22)
        textField.isBordered = false
        textField.backgroundColor = .clear
        textField.focusRingType = .none
        textField.placeholderString = "Type a command..."
        textField.cell?.lineBreakMode = .byTruncatingTail
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        // Update closures
        if let tabField = nsView as? TabAwareTextField {
            tabField.onTab = onTab
            tabField.onEscape = onEscape
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
}
