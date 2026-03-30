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
    var onArrowLeft: () -> Bool
    var onArrowRight: () -> Bool
    var onCmd1: (() -> Void)?
    var onCmd2: (() -> Void)?
    var onCmd3: (() -> Void)?
    var onCmd4: (() -> Void)?

    func makeNSView(context: Context) -> NSTextField {
        let textField = TabAwareTextField()
        textField.delegate = context.coordinator
        textField.onTab = onTab
        textField.onEscape = onEscape
        textField.onCmd1 = onCmd1
        textField.onCmd2 = onCmd2
        textField.onCmd3 = onCmd3
        textField.onCmd4 = onCmd4
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

        let focus = { [weak textField] in
            DispatchQueue.main.async {
                textField?.window?.makeFirstResponder(textField)
            }
        }
        NotificationCenter.default.addObserver(forName: .halfredSearchPanelShown, object: nil, queue: .main) { _ in focus() }
        NotificationCenter.default.addObserver(forName: .halfredFocusInput, object: nil, queue: .main) { _ in focus() }

        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: NSColor(white: 0.40, alpha: 1.0),
                .font: NSFont.systemFont(ofSize: 20, weight: .light),
            ]
        )
        if let tabField = nsView as? TabAwareTextField {
            tabField.onTab = onTab
            tabField.onEscape = onEscape
            tabField.onCmd1 = onCmd1
            tabField.onCmd2 = onCmd2
            tabField.onCmd3 = onCmd3
            tabField.onCmd4 = onCmd4
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
            if commandSelector == #selector(NSResponder.moveLeft(_:)) {
                return parent.onArrowLeft()
            }
            if commandSelector == #selector(NSResponder.moveRight(_:)) {
                return parent.onArrowRight()
            }
            return false
        }
    }
}

// MARK: - Multiline Text Field (for Translate mode)

struct MultilineSearchTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onSubmit: () -> Void
    var onEscape: () -> Void
    var onCmd1: (() -> Void)?
    var onCmd2: (() -> Void)?
    var onCmd3: (() -> Void)?
    var onCmd4: (() -> Void)?

    func makeNSView(context: Context) -> NSScrollView {
        let textView = TabAwareTextView()
        textView.delegate = context.coordinator
        textView.onCmd1 = onCmd1
        textView.onCmd2 = onCmd2
        textView.onCmd3 = onCmd3
        textView.onCmd4 = onCmd4
        textView.onEscape = onEscape
        textView.font = .systemFont(ofSize: 20, weight: .light)
        textView.textColor = .white
        textView.backgroundColor = .clear
        textView.insertionPointColor = .white
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.focusRingType = .none
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.autoresizingMask = [.width]

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.autohidesScrollers = true

        context.coordinator.textView = textView

        let focus = { [weak textView] in
            DispatchQueue.main.async {
                guard let tv = textView else { return }
                tv.window?.makeFirstResponder(tv)
            }
        }
        NotificationCenter.default.addObserver(forName: .halfredSearchPanelShown, object: nil, queue: .main) { _ in focus() }
        NotificationCenter.default.addObserver(forName: .halfredFocusInput, object: nil, queue: .main) { _ in focus() }

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? TabAwareTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        textView.onCmd1 = onCmd1
        textView.onCmd2 = onCmd2
        textView.onCmd3 = onCmd3
        textView.onCmd4 = onCmd4
        textView.onEscape = onEscape
        textView.placeholderString = text.isEmpty ? placeholder : nil

        // Ensure width tracks scroll view
        DispatchQueue.main.async {
            textView.frame.size.width = nsView.contentSize.width
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        let parent: MultilineSearchTextField
        var textView: NSTextView?

        init(_ parent: MultilineSearchTextField) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                // Shift+Enter inserts newline, Enter submits
                if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
                    textView.insertNewlineIgnoringFieldEditor(nil)
                    return true
                }
                parent.onSubmit()
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onEscape()
                return true
            }
            return false
        }
    }
}

// MARK: - Shared Controls

final class TabAwareTextField: NSTextField {
    var onTab: (() -> Void)?
    var onEscape: (() -> Void)?
    var onCmd1: (() -> Void)?
    var onCmd2: (() -> Void)?
    var onCmd3: (() -> Void)?
    var onCmd4: (() -> Void)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            if event.charactersIgnoringModifiers == "1" { onCmd1?(); return true }
            if event.charactersIgnoringModifiers == "2" { onCmd2?(); return true }
            if event.charactersIgnoringModifiers == "3" { onCmd3?(); return true }
            if event.charactersIgnoringModifiers == "4" { onCmd4?(); return true }
        }
        return super.performKeyEquivalent(with: event)
    }
}

final class TabAwareTextView: NSTextView {
    var onCmd1: (() -> Void)?
    var onCmd2: (() -> Void)?
    var onCmd3: (() -> Void)?
    var onCmd4: (() -> Void)?
    var onEscape: (() -> Void)?
    var placeholderString: String?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            if event.charactersIgnoringModifiers == "1" { onCmd1?(); return true }
            if event.charactersIgnoringModifiers == "2" { onCmd2?(); return true }
            if event.charactersIgnoringModifiers == "3" { onCmd3?(); return true }
            if event.charactersIgnoringModifiers == "4" { onCmd4?(); return true }
        }
        return super.performKeyEquivalent(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if string.isEmpty, let placeholder = placeholderString {
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor(white: 0.40, alpha: 1.0),
                .font: NSFont.systemFont(ofSize: 20, weight: .light),
            ]
            let rect = NSRect(x: textContainerInset.width + (textContainer?.lineFragmentPadding ?? 0),
                              y: textContainerInset.height,
                              width: bounds.width, height: bounds.height)
            NSAttributedString(string: placeholder, attributes: attrs).draw(in: rect)
        }
    }

    override var acceptsFirstResponder: Bool { true }
}
