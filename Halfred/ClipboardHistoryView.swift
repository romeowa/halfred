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
        switch item.content {
        case .text(let string):
            VStack(alignment: .leading, spacing: 1) {
                Text(string)
                    .font(.system(size: 13))
                    .foregroundColor(isSelected ? Theme.textPrimary : Theme.textPrimary.opacity(0.9))
                    .lineLimit(2)
                    .truncationMode(.tail)
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
                    Text(ocrText)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.ocrText)
                        .lineLimit(3)
                        .truncationMode(.tail)
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
                Text(url.lastPathComponent)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? Theme.textPrimary : Theme.textPrimary.opacity(0.9))
                    .lineLimit(1)
                Text(url.deletingLastPathComponent().path)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
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
