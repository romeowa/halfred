import AppKit
import SwiftUI

enum ClipboardContent {
    case text(String)
    case image(NSImage)
    case fileURL(URL)
}

struct ClipboardItem: Identifiable {
    let id = UUID()
    let content: ClipboardContent
    let timestamp: Date
    var ocrText: String?
    var ocrInProgress: Bool = false

    var searchableText: String {
        switch content {
        case .text(let str): return str
        case .image: return ocrText ?? ""
        case .fileURL(let url): return url.lastPathComponent
        }
    }
}

final class ClipboardManager: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []

    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let maxItems = 200
    private var ignoredChangeCount: Int?

    func startMonitoring() {
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func checkPasteboard() {
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        // Skip changes we made ourselves
        if let ignored = ignoredChangeCount, currentCount == ignored {
            ignoredChangeCount = nil
            return
        }

        guard let types = pasteboard.types else { return }

        // Check for image first (tiff/png) — screenshot copies etc.
        if types.contains(.tiff) || types.contains(.png) {
            let type: NSPasteboard.PasteboardType = types.contains(.tiff) ? .tiff : .png
            if let data = pasteboard.data(forType: type), let image = NSImage(data: data) {
                let item = ClipboardItem(content: .image(image), timestamp: Date(), ocrInProgress: true)
                let itemId = item.id
                addItem(item)
                OCRService.recognizeText(in: image) { [weak self] text in
                    guard let self else { return }
                    if let index = self.items.firstIndex(where: { $0.id == itemId }) {
                        self.items[index].ocrText = text
                        self.items[index].ocrInProgress = false
                    }
                }
                return
            }
        }

        // Check for file URL
        if types.contains(.fileURL) {
            if let urlData = pasteboard.data(forType: .fileURL),
               let url = URL(dataRepresentation: urlData, relativeTo: nil) {
                let item = ClipboardItem(content: .fileURL(url), timestamp: Date())
                addItem(item)
                return
            }
        }

        // Fallback: plain string
        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            let item = ClipboardItem(content: .text(string), timestamp: Date())
            addItem(item)
        }
    }

    private func addItem(_ item: ClipboardItem) {
        items.insert(item, at: 0)
        if items.count > maxItems {
            items.removeLast(items.count - maxItems)
        }
    }

    func copyToClipboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.content {
        case .text(let string):
            pasteboard.setString(string, forType: .string)
        case .image(let image):
            if let tiffData = image.tiffRepresentation {
                pasteboard.setData(tiffData, forType: .tiff)
            }
        case .fileURL(let url):
            pasteboard.setData(url.dataRepresentation, forType: .fileURL)
            pasteboard.setString(url.path, forType: .string)
        }

        ignoredChangeCount = pasteboard.changeCount
        lastChangeCount = pasteboard.changeCount
    }

    func copyText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        ignoredChangeCount = pasteboard.changeCount
        lastChangeCount = pasteboard.changeCount
    }

    func removeItem(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
    }

    func filteredItems(query: String) -> [ClipboardItem] {
        guard !query.isEmpty else { return items }
        let lowered = query.lowercased()
        return items.filter { $0.searchableText.lowercased().contains(lowered) }
    }
}
