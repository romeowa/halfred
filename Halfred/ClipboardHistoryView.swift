import SwiftUI

struct ClipboardHistoryView: View {
    @ObservedObject var clipboardManager: ClipboardManager
    let query: String
    let selectedIndex: Int
    let onPaste: (ClipboardItem) -> Void
    let onCopyText: (String) -> Void
    let onRemove: (ClipboardItem) -> Void

    private var displayItems: [ClipboardItem] {
        clipboardManager.filteredItems(query: query)
    }

    var body: some View {
        if displayItems.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "clipboard")
                    .font(.system(size: 28))
                    .foregroundColor(Theme.textMuted)
                Text(query.isEmpty ? "No clipboard history yet" : "No matching items")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        } else {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(displayItems.enumerated()), id: \.element.id) { index, item in
                        let isSelected = index == selectedIndex
                        clipboardRow(item: item, isSelected: isSelected)
                            .onTapGesture {
                                onPaste(item)
                            }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
            }
            .frame(maxHeight: 400)
        }
    }

    @ViewBuilder
    private func clipboardRow(item: ClipboardItem, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Theme.accent.opacity(0.2) : Theme.surfaceLight)
                    .frame(width: 30, height: 30)
                Image(systemName: iconName(for: item))
                    .font(.system(size: 13))
                    .foregroundColor(isSelected ? Theme.accent : iconColor(for: item))
            }

            // Content
            contentView(for: item, isSelected: isSelected)

            Spacer()

            // OCR copy button for images
            if case .image = item.content {
                if item.ocrInProgress {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 20, height: 20)
                } else if let ocrText = item.ocrText, !ocrText.isEmpty {
                    Button(action: {
                        clipboardManager.copyText(ocrText)
                        onCopyText(ocrText)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 10))
                            Text("Copy Text")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(Theme.ocrText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Theme.ocrText.opacity(0.15))
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                }
            }

            // Timestamp
            Text(relativeTime(item.timestamp))
                .font(.system(size: 10))
                .foregroundColor(Theme.textMuted)

            // Remove button
            Button(action: { onRemove(item) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Theme.textMuted)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Theme.accent.opacity(0.12) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Theme.accent.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func contentView(for item: ClipboardItem, isSelected: Bool) -> some View {
        let textColor = isSelected ? Theme.textPrimary : Theme.textPrimary.opacity(0.9)

        switch item.content {
        case .text(let string):
            VStack(alignment: .leading, spacing: 1) {
                textPreview(string, font: .system(size: 13), color: textColor)
                Text("\(string.count) chars")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textMuted)
            }

        case .image(let image):
            HStack(spacing: 10) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 50)
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Theme.border, lineWidth: 1)
                    )

                if let ocrText = item.ocrText, !ocrText.isEmpty {
                    textPreview(ocrText, font: .system(size: 11), color: Theme.ocrText)
                } else if item.ocrInProgress {
                    Text("Recognizing text...")
                        .font(.system(size: 11, weight: .light))
                        .foregroundColor(Theme.textMuted)
                        .italic()
                } else {
                    Text("Image")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textMuted)
                }
            }

        case .fileURL(let url):
            VStack(alignment: .leading, spacing: 1) {
                highlightedText(url.lastPathComponent, font: .system(size: 13, weight: .medium), color: textColor)
                    .lineLimit(1)
                Text(url.deletingLastPathComponent().path)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    @ViewBuilder
    private func textPreview(_ text: String, font: Font, color: Color) -> some View {
        let lines = text.components(separatedBy: .newlines)

        if query.isEmpty {
            // No search: show first 5 lines
            let preview = lines.prefix(5).joined(separator: "\n")
            VStack(alignment: .leading, spacing: 0) {
                Text(preview)
                    .font(font)
                    .foregroundColor(color)
                    .lineLimit(5)
                if lines.count > 5 {
                    Text("... +\(lines.count - 5) lines")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textMuted)
                }
            }
        } else {
            // Search: find first matching line, show with ±1 context
            let keyword = query.lowercased()
            if let matchIdx = lines.firstIndex(where: { $0.lowercased().contains(keyword) }) {
                let start = max(0, matchIdx - 1)
                let end = min(lines.count - 1, matchIdx + 1)
                let contextLines = Array(lines[start...end])

                VStack(alignment: .leading, spacing: 0) {
                    if start > 0 {
                        Text("... \(start) lines above")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textMuted)
                    }
                    ForEach(Array(contextLines.enumerated()), id: \.offset) { i, line in
                        highlightedText(line, font: font, color: color)
                            .lineLimit(1)
                    }
                    if end < lines.count - 1 {
                        Text("... \(lines.count - 1 - end) lines below")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textMuted)
                    }
                }
            } else {
                // Shouldn't happen (filtered), but fallback
                Text(lines.prefix(5).joined(separator: "\n"))
                    .font(font)
                    .foregroundColor(color)
                    .lineLimit(5)
            }
        }
    }

    private func highlightedText(_ text: String, font: Font, color: Color) -> Text {
        guard !query.isEmpty else {
            return Text(text).font(font).foregroundColor(color)
        }

        var result = Text("")
        var searchStart = text.startIndex

        while searchStart < text.endIndex,
              let range = text.range(of: query, options: .caseInsensitive, range: searchStart..<text.endIndex) {
            // Text before match
            if searchStart < range.lowerBound {
                result = result + Text(String(text[searchStart..<range.lowerBound]))
                    .font(font).foregroundColor(color)
            }

            // Matched text
            result = result + Text(String(text[range]))
                .font(font)
                .foregroundColor(Theme.accent)
                .bold()

            searchStart = range.upperBound
        }

        // Remaining text after last match
        if searchStart < text.endIndex {
            result = result + Text(String(text[searchStart...]))
                .font(font).foregroundColor(color)
        }

        return result
    }

    private func iconName(for item: ClipboardItem) -> String {
        switch item.content {
        case .text: return "doc.text"
        case .image: return "photo"
        case .fileURL: return "doc.fill"
        }
    }

    private func iconColor(for item: ClipboardItem) -> Color {
        switch item.content {
        case .text: return Theme.typeClipboard
        case .image: return Theme.ocrText
        case .fileURL: return Theme.typeOpen
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        let days = hours / 24
        return "\(days)d"
    }
}
