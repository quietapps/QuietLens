import SwiftUI
import AppKit
import Carbon.HIToolbox

struct GestureSettings: View {
    @EnvironmentObject var settings: FocusLensSettings
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            CCCard("Shake to Toggle") {
                CCRow(icon: "wave.3.right", title: "Enabled") {
                    Toggle("", isOn: $settings.shakeEnabled).labelsHidden()
                }
                if settings.shakeEnabled {
                    Divider()
                    TickSliderRow(icon: "dial.high", title: "Sensitivity",
                                  value: $settings.shakeSensitivity,
                                  ticks: [0.0, 0.25, 0.5, 0.75, 1.0],
                                  labels: ["Very Low", "Low", "Medium", "High", "Very High"])
                    Divider()
                    CCRow(icon: "command", title: "Modifier") {
                        Picker("", selection: $settings.shakeModifier) {
                            ForEach(ShakeModifier.allCases) { Text($0.label).tag($0) }
                        }.labelsHidden().frame(width: 140)
                    }
                }
            }
            CCCard("Global Shortcuts") {
                ShortcutRecorder(label: "Toggle Overlay",
                                 key: $settings.toggleShortcutKey,
                                 mods: $settings.toggleShortcutMods)
                Divider()
                ShortcutRecorder(label: "Open Settings",
                                 key: $settings.settingsShortcutKey,
                                 mods: $settings.settingsShortcutMods)
                Divider()
                ShortcutRecorder(label: "Exclude Current App",
                                 key: $settings.excludeAppShortcutKey,
                                 mods: $settings.excludeAppShortcutMods)
            }
        }
    }
}

struct TickSliderRow: View {
    let icon: String
    let title: String
    @Binding var value: Double
    let ticks: [Double]
    let labels: [String]

    private var currentIndex: Int {
        let i = ticks.enumerated().min { abs($0.element - value) < abs($1.element - value) }?.offset
        return i ?? 0
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.accentColor.opacity(0.15)))
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                    Spacer()
                    Text(labels[currentIndex]).font(.callout).foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    ForEach(Array(ticks.enumerated()), id: \.offset) { idx, t in
                        Button { value = t } label: {
                            Capsule()
                                .fill(idx == currentIndex ? Color.accentColor : Color.secondary.opacity(0.25))
                                .frame(height: 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct ShortcutRecorder: View {
    let label: String
    @Binding var key: UInt16?
    @Binding var mods: UInt
    @State private var recording = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "keyboard")
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.accentColor.opacity(0.15)))
                .foregroundStyle(Color.accentColor)
            Text(label)
            Spacer()
            Button(action: { recording.toggle() }) {
                Text(display).frame(minWidth: 130).padding(.vertical, 4).padding(.horizontal, 10)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .background(KeyCaptureView(active: $recording) { code, modifiers in
                key = code
                mods = Self.carbonMods(from: modifiers)
                recording = false
                NotificationCenter.default.post(name: .focusLensShortcutChanged, object: nil)
            })
            if key != nil {
                Button("Clear") {
                    key = nil
                    mods = 0
                    NotificationCenter.default.post(name: .focusLensShortcutChanged, object: nil)
                }
            }
        }
    }

    private var display: String {
        if recording { return "Press keys…" }
        guard let k = key else { return "Not set" }
        return Self.modString(mods) + Self.keyString(k)
    }

    static func carbonMods(from flags: NSEvent.ModifierFlags) -> UInt {
        var m: UInt = 0
        if flags.contains(.command) { m |= UInt(cmdKey) }
        if flags.contains(.option) { m |= UInt(optionKey) }
        if flags.contains(.shift) { m |= UInt(shiftKey) }
        if flags.contains(.control) { m |= UInt(controlKey) }
        return m
    }
    static func modString(_ m: UInt) -> String {
        var s = ""
        if m & UInt(controlKey) != 0 { s += "⌃" }
        if m & UInt(optionKey) != 0 { s += "⌥" }
        if m & UInt(shiftKey) != 0 { s += "⇧" }
        if m & UInt(cmdKey) != 0 { s += "⌘" }
        return s
    }
    static func keyString(_ k: UInt16) -> String {
        let map: [UInt16: String] = [
            0:"A",1:"S",2:"D",3:"F",4:"H",5:"G",6:"Z",7:"X",8:"C",9:"V",
            11:"B",12:"Q",13:"W",14:"E",15:"R",16:"Y",17:"T",
            31:"O",32:"U",34:"I",35:"P",37:"L",38:"J",40:"K",45:"N",46:"M",
            49:"Space",36:"↩",53:"⎋",51:"⌫",48:"⇥",
            123:"←",124:"→",125:"↓",126:"↑"
        ]
        return map[k] ?? "Key\(k)"
    }
}

struct KeyCaptureView: NSViewRepresentable {
    @Binding var active: Bool
    var onCapture: (UInt16, NSEvent.ModifierFlags) -> Void

    func makeNSView(context: Context) -> NSView { CaptureView() }
    func updateNSView(_ nsView: NSView, context: Context) {
        guard let v = nsView as? CaptureView else { return }
        v.onCapture = onCapture
        v.active = active
        if active { DispatchQueue.main.async { v.window?.makeFirstResponder(v) } }
    }
    final class CaptureView: NSView {
        var onCapture: ((UInt16, NSEvent.ModifierFlags) -> Void)?
        var active: Bool = false
        override var acceptsFirstResponder: Bool { true }
        override func keyDown(with event: NSEvent) {
            guard active else { super.keyDown(with: event); return }
            onCapture?(event.keyCode, event.modifierFlags.intersection(.deviceIndependentFlagsMask))
        }
    }
}
