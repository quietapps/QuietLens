import SwiftUI
import AppKit

struct GestureScreen: View {
    @EnvironmentObject var settings: QuietLensSettings
    @Environment(\.colorScheme) var scheme
    var search: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeader("Gestures", subtitle: "Shake, shortcuts, and pointer behavior.")

            if match("shake toggle peek sensitivity modifier hold") {
                SectionLabel(text: "Shake to Toggle")
                GlassPanel {
                    SettingsRow(icon: "wand.and.stars", title: "Enabled",
                                subtitle: "Wiggle the cursor to toggle the overlay.",
                                isFirst: true,
                                trailing: { GlassSwitch(isOn: $settings.shakeEnabled) })
                    if settings.shakeEnabled {
                        SettingsRow(icon: "speedometer", title: "Sensitivity",
                                    trailing: {
                            Text(sensLabel)
                                .font(FL.T.bodyR())
                                .foregroundStyle(FL.C.text2(scheme))
                        },
                                    below: {
                            SensitivityBar(value: $settings.shakeSensitivity).padding(.top, 6)
                        })
                        SettingsRow(icon: "command", title: "Hold modifier",
                                    subtitle: "Used for shake-to-peek.",
                                    trailing: {
                            GlassPicker(selection: $settings.shakeModifier,
                                        items: ShakeModifier.allCases,
                                        label: { $0.label })
                        })
                    }
                }
            }

            if match("global shortcuts hotkey keyboard pin exclude toggle") {
                SectionLabel(text: "Global Shortcuts")
                GlassPanel {
                    ShortcutRow(label: "Toggle overlay", icon: "keyboard",
                                key: $settings.toggleShortcutKey,
                                mods: $settings.toggleShortcutMods, isFirst: true)
                    ShortcutRow(label: "Open Settings", icon: "gearshape",
                                key: $settings.settingsShortcutKey,
                                mods: $settings.settingsShortcutMods)
                    ShortcutRow(label: "Exclude current app", icon: "minus.circle",
                                key: $settings.excludeAppShortcutKey,
                                mods: $settings.excludeAppShortcutMods)
                    ShortcutRow(label: "Pin current window", icon: "pin",
                                key: $settings.pinShortcutKey,
                                mods: $settings.pinShortcutMods)
                }
            }

            if match("pointer cursor hover halo") {
                SectionLabel(text: "Pointer")
                GlassPanel {
                    SettingsRow(icon: "cursorarrow.rays",
                                title: "Cursor halo",
                                subtitle: "Subtle ring around the cursor.",
                                isFirst: true,
                                comingSoon: true,
                                trailing: { GlassSwitch(isOn: .constant(false)) })
                    SettingsRow(icon: "rectangle.dashed",
                                title: "Focus on hover",
                                subtitle: "Switch focus when you hover a window.",
                                comingSoon: true,
                                trailing: { GlassSwitch(isOn: .constant(false)) })
                }
            }
        }
    }

    private var sensLabel: String {
        switch settings.shakeSensitivity {
        case ..<0.15: return "Very Low"
        case ..<0.4: return "Low"
        case ..<0.65: return "Medium"
        case ..<0.9: return "High"
        default: return "Very High"
        }
    }

    private func match(_ keywords: String) -> Bool {
        guard !search.isEmpty else { return true }
        return keywords.lowercased().contains(search.lowercased())
    }
}

struct SensitivityBar: View {
    @Binding var value: Double
    @Environment(\.colorScheme) var scheme
    let ticks: [Double] = [0.0, 0.25, 0.5, 0.75, 1.0]

    var body: some View {
        let activeIdx = ticks.enumerated().min { abs($0.element - value) < abs($1.element - value) }?.offset ?? 0
        HStack(spacing: 6) {
            ForEach(0..<5, id: \.self) { i in
                Button {
                    value = ticks[i]
                } label: {
                    Capsule()
                        .fill(i <= activeIdx ? FL.C.accent : (scheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.12)))
                        .frame(maxWidth: .infinity)
                        .frame(height: 8)
                        .shadow(color: i <= activeIdx ? FL.C.accentGlow : .clear, radius: 4)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct ShortcutRow: View {
    let label: String
    let icon: String
    @Binding var key: UInt16?
    @Binding var mods: UInt
    var isFirst: Bool = false
    @State private var recording = false

    var body: some View {
        SettingsRow(icon: icon, title: label, isFirst: isFirst, trailing: {
            HStack(spacing: 6) {
                Button {
                    recording.toggle()
                } label: {
                    Kbd(text: display).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(KeyCaptureView(active: $recording) { code, modifiers in
                    key = code
                    mods = ShortcutRecorder.carbonMods(from: modifiers)
                    recording = false
                    NotificationCenter.default.post(name: .quietLensShortcutChanged, object: nil)
                })
                if key != nil {
                    DangerCircleButton(icon: "trash") {
                        key = nil
                        mods = 0
                        NotificationCenter.default.post(name: .quietLensShortcutChanged, object: nil)
                    }
                }
            }
        })
    }

    private var display: String {
        if recording { return "Press keys…" }
        guard let k = key else { return "" }
        return ShortcutRecorder.modString(mods) + " " + ShortcutRecorder.keyString(k)
    }
}
