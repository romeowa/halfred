import AppKit
import SwiftUI

enum ClipboardContent {
    case text(String)
    case image(NSImage)
    case fileURL(URL)
}

struct ClipboardItem: Identifiable {
    let id: UUID
    let content: ClipboardContent
    let timestamp: Date
    var ocrText: String?
    var ocrInProgress: Bool = false

    init(id: UUID = UUID(), content: ClipboardContent, timestamp: Date, ocrText: String? = nil, ocrInProgress: Bool = false) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
        self.ocrText = ocrText
        self.ocrInProgress = ocrInProgress
    }

    var searchableText: String {
        switch content {
        case .text(let str): return str
        case .image: return ocrText ?? ""
        case .fileURL(let url): return url.lastPathComponent
        }
    }
}

// MARK: - Persistence Format

private struct PersistedItem: Codable {
    let id: String
    let kind: String // "text" | "image" | "fileURL"
    let timestamp: Date
    let text: String?
    let imageFileName: String?
    let fileURL: String?
    let ocrText: String?
}

private struct PersistedFile: Codable {
    let items: [PersistedItem]
}

final class ClipboardManager: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []

    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let maxItems = 200
    private var ignoredChangeCount: Int?
    private let saveQueue = DispatchQueue(label: "halfred.clipboard.save", qos: .utility)
    private var saveWorkItem: DispatchWorkItem?

    private var storageDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".halfred")
            .appendingPathComponent("clipboard")
    }

    private var metadataFile: URL {
        storageDir.appendingPathComponent("items.json")
    }

    init() {
        load()
    }

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
                        self.schedulePersist()
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
            let removed = items.suffix(items.count - maxItems)
            for r in removed { deleteImageFile(for: r) }
            items.removeLast(items.count - maxItems)
        }
        schedulePersist()
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
        deleteImageFile(for: item)
        items.removeAll { $0.id == item.id }
        schedulePersist()
    }

    func filteredItems(query: String) -> [ClipboardItem] {
        guard !query.isEmpty else { return items }
        let lowered = query.lowercased()
        return items.filter { $0.searchableText.lowercased().contains(lowered) }
    }

    // MARK: - Persistence

    private func imageURL(for id: UUID) -> URL {
        storageDir.appendingPathComponent("\(id.uuidString).png")
    }

    private func deleteImageFile(for item: ClipboardItem) {
        if case .image = item.content {
            try? FileManager.default.removeItem(at: imageURL(for: item.id))
        }
    }

    private func schedulePersist() {
        saveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.persist()
        }
        saveWorkItem = work
        saveQueue.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func persist() {
        let snapshot = items
        do {
            try FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)

            var persisted: [PersistedItem] = []
            for item in snapshot {
                switch item.content {
                case .text(let str):
                    persisted.append(PersistedItem(
                        id: item.id.uuidString, kind: "text", timestamp: item.timestamp,
                        text: str, imageFileName: nil, fileURL: nil, ocrText: nil
                    ))
                case .image(let image):
                    let url = imageURL(for: item.id)
                    if !FileManager.default.fileExists(atPath: url.path) {
                        if let tiff = image.tiffRepresentation,
                           let rep = NSBitmapImageRep(data: tiff),
                           let png = rep.representation(using: .png, properties: [:]) {
                            try? png.write(to: url)
                        }
                    }
                    persisted.append(PersistedItem(
                        id: item.id.uuidString, kind: "image", timestamp: item.timestamp,
                        text: nil, imageFileName: "\(item.id.uuidString).png", fileURL: nil, ocrText: item.ocrText
                    ))
                case .fileURL(let fileURL):
                    persisted.append(PersistedItem(
                        id: item.id.uuidString, kind: "fileURL", timestamp: item.timestamp,
                        text: nil, imageFileName: nil, fileURL: fileURL.absoluteString, ocrText: nil
                    ))
                }
            }

            let file = PersistedFile(items: persisted)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted]
            let data = try encoder.encode(file)
            try data.write(to: metadataFile)

            // Clean up orphaned images
            let validNames = Set(persisted.compactMap { $0.imageFileName })
            if let contents = try? FileManager.default.contentsOfDirectory(at: storageDir, includingPropertiesForKeys: nil) {
                for url in contents where url.pathExtension == "png" && !validNames.contains(url.lastPathComponent) {
                    try? FileManager.default.removeItem(at: url)
                }
            }
        } catch {
            NSLog("Halfred: Failed to persist clipboard: \(error)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: metadataFile.path) else { return }
        do {
            let data = try Data(contentsOf: metadataFile)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let file = try decoder.decode(PersistedFile.self, from: data)

            var loaded: [ClipboardItem] = []
            for p in file.items {
                guard let uuid = UUID(uuidString: p.id) else { continue }
                switch p.kind {
                case "text":
                    if let t = p.text {
                        loaded.append(ClipboardItem(id: uuid, content: .text(t), timestamp: p.timestamp))
                    }
                case "image":
                    if let name = p.imageFileName {
                        let url = storageDir.appendingPathComponent(name)
                        if let image = NSImage(contentsOf: url) {
                            loaded.append(ClipboardItem(id: uuid, content: .image(image), timestamp: p.timestamp, ocrText: p.ocrText))
                        }
                    }
                case "fileURL":
                    if let s = p.fileURL, let url = URL(string: s) {
                        loaded.append(ClipboardItem(id: uuid, content: .fileURL(url), timestamp: p.timestamp))
                    }
                default:
                    break
                }
            }
            items = loaded
            NSLog("Halfred: Loaded \(items.count) clipboard items")
        } catch {
            NSLog("Halfred: Failed to load clipboard: \(error)")
        }
    }
}
