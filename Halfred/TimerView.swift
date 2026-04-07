import SwiftUI

struct TimerPresetView: View {
    let onDismiss: () -> Void

    @State private var timerName: String = ""
    @State private var customMinutes: String = ""
    @State private var customSeconds: String = ""
    @State private var showCustom = false
    @State private var hoveredPreset: Int?

    var body: some View {
        VStack(spacing: 0) {
            // Name field
            HStack(spacing: 8) {
                Image(systemName: "tag")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textMuted)
                TextField("Timer name (optional)", text: $timerName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textPrimary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border.opacity(0.5), lineWidth: 1))
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Presets
            HStack(spacing: 10) {
                presetButton(label: "3", unit: "min", seconds: 180)
                presetButton(label: "5", unit: "min", seconds: 300)
                presetButton(label: "10", unit: "min", seconds: 600)

                // Custom toggle
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showCustom.toggle() } }) {
                    VStack(spacing: 4) {
                        Image(systemName: "dial.medium.fill")
                            .font(.system(size: 22))
                            .foregroundColor(showCustom ? Theme.accent : Theme.textMuted)
                        Text("Custom")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(showCustom ? Theme.textPrimary : Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(showCustom ? Theme.accent.opacity(0.1) : Theme.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(showCustom ? Theme.accent.opacity(0.4) : Theme.border.opacity(0.5), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .onHover { h in if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, showCustom ? 12 : 18)

            // Custom input row
            if showCustom {
                HStack(spacing: 10) {
                    HStack(spacing: 6) {
                        TextField("0", text: $customMinutes)
                            .textFieldStyle(.plain)
                            .font(.system(size: 20, weight: .medium, design: .monospaced))
                            .foregroundColor(Theme.textPrimary)
                            .frame(width: 36)
                            .multilineTextAlignment(.center)
                        Text("min")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.textMuted)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.surface))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border.opacity(0.5), lineWidth: 1))

                    HStack(spacing: 6) {
                        TextField("0", text: $customSeconds)
                            .textFieldStyle(.plain)
                            .font(.system(size: 20, weight: .medium, design: .monospaced))
                            .foregroundColor(Theme.textPrimary)
                            .frame(width: 36)
                            .multilineTextAlignment(.center)
                        Text("sec")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.textMuted)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.surface))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border.opacity(0.5), lineWidth: 1))

                    Spacer()

                    Button(action: startCustomTimer) {
                        HStack(spacing: 5) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 10))
                            Text("Start")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.accent))
                    }
                    .buttonStyle(.plain)
                    .onHover { h in if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    @ViewBuilder
    private func presetButton(label: String, unit: String, seconds: Int) -> some View {
        let isHovered = hoveredPreset == seconds
        Button(action: { startTimer(seconds: seconds) }) {
            VStack(spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(label)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(isHovered ? Theme.accent : Theme.textPrimary)
                    Text(unit)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.textMuted)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovered ? Theme.accent.opacity(0.1) : Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isHovered ? Theme.accent.opacity(0.4) : Theme.border.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.15)) { hoveredPreset = h ? seconds : nil }
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }

    private func startTimer(seconds: Int) {
        guard seconds > 0 else { return }
        let name = timerName.trimmingCharacters(in: .whitespacesAndNewlines)
        TimerManager.shared.startNew(seconds: seconds, name: name.isEmpty ? nil : name)
        timerName = ""
        onDismiss()
    }

    private func startCustomTimer() {
        let m = Int(customMinutes) ?? 0
        let s = Int(customSeconds) ?? 0
        startTimer(seconds: m * 60 + s)
    }
}
