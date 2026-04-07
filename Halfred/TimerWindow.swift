import AppKit
import SwiftUI
import UserNotifications

// MARK: - Timer Manager (multi-instance)

final class TimerManager {
    static let shared = TimerManager()

    private var instances: [UUID: TimerInstance] = [:]

    func startNew(seconds: Int, name: String?) {
        let instance = TimerInstance()
        instances[instance.id] = instance
        instance.start(seconds: seconds, name: name) { [weak self] id in
            self?.instances.removeValue(forKey: id)
        }
    }
}

// MARK: - Single Timer Instance

private final class TimerInstance {
    let id = UUID()
    private var window: NSWindow?
    private var viewModel = TimerViewModel()

    func start(seconds: Int, name: String?, onClose: @escaping (UUID) -> Void) {
        let instanceId = id
        viewModel.start(totalSeconds: seconds, name: name)

        let contentView = TimerContentView(viewModel: viewModel, onClose: { [weak self] in
            self?.viewModel.stop()
            self?.window?.close()
            self?.window = nil
            onClose(instanceId)
        })
        let hostingController = NSHostingController(rootView: contentView)

        let window = DraggableTimerWindow(contentViewController: hostingController)
        window.title = ""
        window.styleMask = [.borderless, .resizable]
        window.setContentSize(NSSize(width: 200, height: 220))
        window.minSize = NSSize(width: 160, height: 180)
        window.maxSize = NSSize(width: 400, height: 440)
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.onClose = { [weak self] in
            self?.viewModel.stop()
            self?.window?.close()
            self?.window = nil
            onClose(instanceId)
        }

        // Stagger position based on existing timer count
        if let screen = NSScreen.main {
            let count = TimerManager.shared.instanceCount
            let screenFrame = screen.visibleFrame
            let offset = CGFloat(count) * 30
            let x = screenFrame.maxX - 220 - offset
            let y = screenFrame.maxY - 240 - offset
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        window.makeKeyAndOrderFront(nil)
        self.window = window
    }
}

extension TimerManager {
    var instanceCount: Int { instances.count }
}

// MARK: - Timer ViewModel

final class TimerViewModel: ObservableObject {
    @Published var remainingSeconds: Int = 0
    @Published var totalSeconds: Int = 0
    @Published var name: String?
    @Published var isRunning = false
    @Published var isPaused = false
    @Published var isFinished = false
    @Published var isLightTheme = false

    private var timer: Timer?

    func start(totalSeconds: Int, name: String?) {
        stop()
        self.totalSeconds = totalSeconds
        self.remainingSeconds = totalSeconds
        self.name = name
        self.isRunning = true
        self.isPaused = false
        self.isFinished = false
        startTimer()
    }

    func addTime(_ seconds: Int) {
        remainingSeconds = max(0, remainingSeconds + seconds)
        totalSeconds = max(totalSeconds, totalSeconds + seconds)
        if isFinished && seconds > 0 {
            isFinished = false
            isRunning = true
            isPaused = false
            startTimer()
        }
    }

    func togglePause() {
        if isPaused {
            isPaused = false
            startTimer()
        } else {
            isPaused = true
            timer?.invalidate()
            timer = nil
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        isPaused = false
        isFinished = false
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.remainingSeconds > 0 {
                self.remainingSeconds -= 1
            }
            if self.remainingSeconds == 0 {
                self.timer?.invalidate()
                self.timer = nil
                self.isRunning = false
                self.isFinished = true
                self.playAlarm()
            }
        }
    }

    private func playAlarm() {
        // Sound
        NSSound(named: .init("Funk"))?.play()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            NSSound(named: .init("Funk"))?.play()
        }

        // System notification
        let content = UNMutableNotificationContent()
        content.title = name ?? "Timer"
        let h = totalSeconds / 3600, m = (totalSeconds % 3600) / 60, s = totalSeconds % 60
        var parts: [String] = []
        if h > 0 { parts.append("\(h)h") }
        if m > 0 { parts.append("\(m)m") }
        if s > 0 { parts.append("\(s)s") }
        content.body = "\(parts.joined(separator: " ")) timer is done."
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(totalSeconds - remainingSeconds) / Double(totalSeconds)
    }

    var timeString: String {
        let h = remainingSeconds / 3600
        let m = (remainingSeconds % 3600) / 60
        let s = remainingSeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Timer Theme Colors

struct TimerTheme {
    let background: Color
    let backgroundMaterial: Color
    let surface: Color
    let surfaceLight: Color
    let border: Color
    let textPrimary: Color
    let textSecondary: Color
    let textMuted: Color
    let accent: Color
    let success: Color

    static let dark = TimerTheme(
        background: Theme.background,
        backgroundMaterial: Theme.background.opacity(0.75),
        surface: Theme.surface,
        surfaceLight: Theme.surfaceLight,
        border: Theme.border,
        textPrimary: .white,
        textSecondary: Theme.textSecondary,
        textMuted: Theme.textMuted,
        accent: Theme.accent,
        success: Theme.typeApp
    )

    static let light = TimerTheme(
        background: Color(red: 0.97, green: 0.97, blue: 0.97),
        backgroundMaterial: Color.white.opacity(0.85),
        surface: Color.white,
        surfaceLight: Color(red: 0.93, green: 0.93, blue: 0.93),
        border: Color(red: 0.85, green: 0.85, blue: 0.85),
        textPrimary: Color(red: 0.1, green: 0.1, blue: 0.1),
        textSecondary: Color(red: 0.35, green: 0.35, blue: 0.35),
        textMuted: Color(red: 0.55, green: 0.55, blue: 0.55),
        accent: Theme.accent,
        success: Color(red: 0.2, green: 0.75, blue: 0.35)
    )
}

// MARK: - Timer Content View

struct TimerContentView: View {
    @ObservedObject var viewModel: TimerViewModel
    let onClose: () -> Void

    @State private var isHoveringClose = false
    @State private var isHoveringTheme = false
    @State private var hoveredControl: String?
    @State private var pulseFinished = false
    @State private var isEditingName = false

    private var t: TimerTheme { viewModel.isLightTheme ? .light : .dark }

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / 200, geo.size.height / 220)
            let ringSize = 110 * scale
            let ringWidth = 6 * scale

            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, viewModel.isLightTheme ? .light : .dark)
                RoundedRectangle(cornerRadius: 20)
                    .fill(t.backgroundMaterial)
                RoundedRectangle(cornerRadius: 20)
                    .stroke(t.border.opacity(0.4), lineWidth: 0.5)

                VStack(spacing: 0) {
                    // Header
                    HStack(spacing: 6) {
                        if isEditingName {
                            TimerNameField(
                                text: Binding(
                                    get: { viewModel.name ?? "" },
                                    set: { viewModel.name = $0.isEmpty ? nil : $0 }
                                ),
                                isLight: viewModel.isLightTheme,
                                onDone: { isEditingName = false }
                            )
                        } else if let name = viewModel.name, !name.isEmpty {
                            Text(name)
                                .font(.system(size: 11 * scale, weight: .semibold))
                                .foregroundColor(t.textSecondary)
                                .lineLimit(1)
                                .onTapGesture { isEditingName = true }
                        } else {
                            Text("Add name")
                                .font(.system(size: 11 * scale))
                                .foregroundColor(t.textMuted.opacity(0.5))
                                .onTapGesture { isEditingName = true }
                        }
                        Spacer()

                        // Theme toggle
                        Button(action: { viewModel.isLightTheme.toggle() }) {
                            Image(systemName: viewModel.isLightTheme ? "moon.fill" : "sun.max.fill")
                                .font(.system(size: 9 * scale, weight: .bold))
                                .foregroundColor(isHoveringTheme ? t.textPrimary : t.textMuted)
                                .frame(width: 18 * scale, height: 18 * scale)
                                .background(Circle().fill(isHoveringTheme ? t.surfaceLight : Color.clear))
                        }
                        .buttonStyle(.plain)
                        .onHover { h in
                            isHoveringTheme = h
                            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                        }

                        // Close
                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.system(size: 9 * scale, weight: .bold))
                                .foregroundColor(isHoveringClose ? t.textPrimary : t.textMuted)
                                .frame(width: 18 * scale, height: 18 * scale)
                                .background(Circle().fill(isHoveringClose ? t.surfaceLight : Color.clear))
                        }
                        .buttonStyle(.plain)
                        .onHover { h in
                            isHoveringClose = h
                            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                        }
                    }
                    .padding(.top, 10 * scale)
                    .padding(.horizontal, 12 * scale)

                    Spacer(minLength: 0)

                    if viewModel.isFinished {
                        finishedView(ringSize: ringSize, ringWidth: ringWidth, scale: scale)
                    } else {
                        timerView(ringSize: ringSize, ringWidth: ringWidth, scale: scale)
                    }

                    Spacer(minLength: 0)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.isLightTheme)
        }
    }

    // MARK: - Timer Running

    private func timerView(ringSize: CGFloat, ringWidth: CGFloat, scale: CGFloat) -> some View {
        VStack(spacing: 10 * scale) {
            ZStack {
                Circle()
                    .stroke(t.surfaceLight.opacity(0.5), lineWidth: ringWidth)
                    .frame(width: ringSize, height: ringSize)

                Circle()
                    .trim(from: 0, to: viewModel.progress)
                    .stroke(
                        progressGradient,
                        style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                    )
                    .frame(width: ringSize, height: ringSize)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: viewModel.progress)

                // Glow at tip
                Circle()
                    .fill(t.accent.opacity(0.3))
                    .frame(width: ringWidth * 3, height: ringWidth * 3)
                    .blur(radius: 4)
                    .offset(tipOffset(ringSize: ringSize))
                    .animation(.linear(duration: 1), value: viewModel.progress)
                    .opacity(viewModel.progress > 0.02 ? 1 : 0)

                VStack(spacing: 2) {
                    let hasHours = viewModel.remainingSeconds >= 3600
                    Text(viewModel.timeString)
                        .font(.system(size: (hasHours ? 18 : 26) * scale, weight: .semibold, design: .monospaced))
                        .foregroundColor(t.textPrimary)

                    if viewModel.isPaused {
                        Text("PAUSED")
                            .font(.system(size: 9 * scale, weight: .bold))
                            .foregroundColor(t.accent)
                            .tracking(1.5)
                    }
                }
            }

            // Controls
            HStack(spacing: 6 * scale) {
                timeAdjustButton(label: "-1m", seconds: -60, scale: scale)
                timeAdjustButton(label: "-30s", seconds: -30, scale: scale)

                Button(action: { viewModel.togglePause() }) {
                    Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 12 * scale))
                        .foregroundColor(hoveredControl == "pause" ? t.textPrimary : t.textSecondary)
                        .frame(width: 32 * scale, height: 32 * scale)
                        .background(Circle().fill(hoveredControl == "pause" ? t.surfaceLight : t.surface))
                        .overlay(Circle().stroke(t.border.opacity(0.3), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .onHover { h in
                    hoveredControl = h ? "pause" : nil
                    if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }

                timeAdjustButton(label: "+30s", seconds: 30, scale: scale)
                timeAdjustButton(label: "+1m", seconds: 60, scale: scale)
            }
        }
    }

    @ViewBuilder
    private func timeAdjustButton(label: String, seconds: Int, scale: CGFloat) -> some View {
        let id = label
        Button(action: { viewModel.addTime(seconds) }) {
            Text(label)
                .font(.system(size: 10 * scale, weight: .medium))
                .foregroundColor(hoveredControl == id ? t.textPrimary : t.textMuted)
                .frame(width: 30 * scale, height: 24 * scale)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(hoveredControl == id ? t.surfaceLight : t.surface.opacity(0.6))
                )
        }
        .buttonStyle(.plain)
        .onHover { h in
            hoveredControl = h ? id : nil
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }

    // MARK: - Finished

    private func finishedView(ringSize: CGFloat, ringWidth: CGFloat, scale: CGFloat) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(t.success.opacity(0.1))
                    .frame(width: ringSize, height: ringSize)
                Circle()
                    .stroke(t.success.opacity(0.3), lineWidth: ringWidth)
                    .frame(width: ringSize, height: ringSize)

                VStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 28 * scale, weight: .semibold))
                        .foregroundColor(t.success)
                    Text("Done")
                        .font(.system(size: 14 * scale, weight: .semibold))
                        .foregroundColor(t.success)
                }
                .scaleEffect(pulseFinished ? 1.0 : 0.8)
                .opacity(pulseFinished ? 1.0 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: pulseFinished)
            }
        }
        .onAppear { pulseFinished = true }
    }

    // MARK: - Helpers

    private var progressGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: [t.accent.opacity(0.6), t.accent]),
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360 * viewModel.progress)
        )
    }

    private func tipOffset(ringSize: CGFloat) -> CGSize {
        let angle = Angle.degrees(360 * viewModel.progress - 90)
        let r = ringSize / 2
        return CGSize(
            width: r * CGFloat(cos(angle.radians)),
            height: r * CGFloat(sin(angle.radians))
        )
    }
}

// MARK: - Timer Name Field (AppKit, supports Korean IME)

struct TimerNameField: NSViewRepresentable {
    @Binding var text: String
    var isLight: Bool = false
    var onDone: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.delegate = context.coordinator
        field.stringValue = text
        field.font = .systemFont(ofSize: 11, weight: .semibold)
        field.textColor = isLight ? .black : .white
        field.backgroundColor = isLight ? .white : NSColor(Theme.surface)
        field.isBordered = false
        field.focusRingType = .none
        field.bezelStyle = .roundedBezel
        field.placeholderString = "Timer name"
        field.cell?.wraps = false
        field.cell?.isScrollable = true

        field.wantsLayer = true
        field.layer?.cornerRadius = 4
        field.layer?.borderWidth = 1
        field.layer?.borderColor = NSColor(Theme.accent.opacity(0.4)).cgColor

        DispatchQueue.main.async {
            field.window?.makeFirstResponder(field)
            field.currentEditor()?.selectAll(nil)
        }

        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.textColor = isLight ? .black : .white
        nsView.backgroundColor = isLight ? .white : NSColor(Theme.surface)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: TimerNameField
        init(_ parent: TimerNameField) { self.parent = parent }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onDone()
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onDone()
                return true
            }
            return false
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            parent.onDone()
        }
    }
}

// MARK: - Draggable Window

final class DraggableTimerWindow: NSWindow {
    var onClose: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            onClose?()
        } else {
            super.keyDown(with: event)
        }
    }

    override var canBecomeKey: Bool { true }
}
