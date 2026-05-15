import SwiftUI
import AppKit

struct AppearanceSettings: View {
    @EnvironmentObject var settings: FocusLensSettings
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            CCCard("Mode") {
                Picker("", selection: $settings.overlayMode) {
                    ForEach(OverlayMode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            CCCard("Blur & Opacity") {
                SliderRow(icon: "drop.fill", title: "Blur Radius",
                          value: $settings.blurRadius, range: 0...50,
                          display: "\(Int(round(settings.blurRadius)))")
                Divider()
                SliderRow(icon: "circle.lefthalf.filled", title: "Opacity",
                          value: $settings.overlayOpacity, range: 0.1...1.0,
                          display: "\(Int(round(settings.overlayOpacity * 100)))%")
            }

            CCCard("Tint") {
                ColorCircleRow(hex: $settings.tintColorHex,
                               useSystem: $settings.useSystemTint)
                Divider()
                CCRow(icon: "rectangle.lefthalf.inset.filled", title: "Gradient") {
                    Toggle("", isOn: $settings.gradientEnabled).labelsHidden()
                }
                if settings.gradientEnabled {
                    Divider()
                    ColorCircleRow(hex: $settings.tintColor2Hex,
                                   useSystem: .constant(false),
                                   label: "Second")
                    Divider()
                    SliderRow(icon: "arrow.up.right", title: "Angle",
                              value: $settings.gradientAngle, range: 0...360,
                              display: "\(Int(settings.gradientAngle))°")
                }
            }

            CCCard("Effects") {
                SliderRow(icon: "circle.grid.cross", title: "Film Grain",
                          value: $settings.grainIntensity, range: 0...1,
                          display: "\(Int(round(settings.grainIntensity * 100)))%")
                Divider()
                CCRow(icon: "camera.filters", title: "Grayscale Background") {
                    Toggle("", isOn: $settings.grayscale).labelsHidden()
                }
            }

            CCCard("Shader") {
                Picker("", selection: $settings.shaderMode) {
                    ForEach(ShaderMode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                if settings.shaderMode != .staticMode {
                    Divider()
                    SliderRow(icon: "speedometer", title: "Animation Speed",
                              value: $settings.animationSpeed, range: 0.25...3.0,
                              display: String(format: "%.1fx", settings.animationSpeed))
                }
            }

            CCCard("Active Window Glow") {
                CCRow(icon: "sparkles", title: "Edge Glow",
                      subtitle: "Soft halo around the focused window") {
                    Toggle("", isOn: $settings.edgeGlowEnabled).labelsHidden()
                }
                if settings.edgeGlowEnabled {
                    Divider()
                    SliderRow(icon: "scope", title: "Glow Radius",
                              value: $settings.edgeGlowRadius, range: 2...30,
                              display: "\(Int(round(settings.edgeGlowRadius)))")
                }
            }

            CCCard("Backdrop") {
                Picker("", selection: $settings.backdropMode) {
                    ForEach(BackdropMode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                if settings.backdropMode == .image {
                    Divider()
                    HStack {
                        Image(systemName: "photo")
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.accentColor.opacity(0.15)))
                            .foregroundStyle(Color.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Custom Image")
                            Text(settings.backdropImagePath ?? "None selected")
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                        }
                        Spacer()
                        Button("Choose…") { pickBackdropImage() }
                        if settings.backdropImagePath != nil {
                            Button {
                                settings.backdropImagePath = nil
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else if settings.backdropMode == .wallpaper {
                    Divider()
                    Text("Uses your current desktop wallpaper as the dim layer.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }

            CCCard("Transitions") {
                SliderRow(icon: "timer", title: "Fade Duration",
                          value: $settings.fadeDuration, range: 0.05...1.0,
                          display: "\(Int(settings.fadeDuration * 1000))ms")
            }
        }
    }
}

struct ColorCircleRow: View {
    @Binding var hex: String
    @Binding var useSystem: Bool
    var label: String? = nil
    @State private var pickerColor: Color = .black

    private static let presets: [String] = [
        "#0A84FF", "#BF5AF2", "#FF375F", "#FF453A", "#FF9F0A",
        "#FFD60A", "#30D158", "#8E8E93", "#000000"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if let label { Text(label).font(.callout) }
                Spacer()
                Button {
                    useSystem = true
                } label: {
                    Text("As System")
                        .font(.callout)
                        .foregroundStyle(useSystem ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(AngularGradient(
                            gradient: Gradient(colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red]),
                            center: .center))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle().strokeBorder(isCustom ? Color.white : .clear, lineWidth: 2)
                        )
                    ColorPicker("", selection: $pickerColor, supportsOpacity: false)
                        .labelsHidden()
                        .opacity(0.02)
                        .frame(width: 32, height: 32)
                        .allowsHitTesting(true)
                }
                ForEach(Self.presets, id: \.self) { h in
                    Button {
                        hex = h
                        useSystem = false
                    } label: {
                        Circle()
                            .fill(Color(nsColor: NSColor(hex: h) ?? .black))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle().strokeBorder(selectedHex == h ? Color.white : .clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .onAppear {
                pickerColor = Color(nsColor: NSColor(hex: hex) ?? .black)
            }
            .onChange(of: pickerColor) { _, newValue in
                let ns = NSColor(newValue).usingColorSpace(.sRGB) ?? .black
                let newHex = ns.toHex()
                if newHex != hex {
                    hex = newHex
                    useSystem = false
                }
            }
            .onChange(of: hex) { _, newHex in
                let ns = NSColor(hex: newHex) ?? .black
                let c = Color(nsColor: ns)
                if NSColor(c).toHex() != NSColor(pickerColor).toHex() {
                    pickerColor = c
                }
            }
        }
    }

    private var selectedHex: String {
        useSystem ? "" : hex.uppercased()
    }
    private var isCustom: Bool {
        !useSystem && !Self.presets.map { $0.uppercased() }.contains(hex.uppercased())
    }
}

struct TintPresetRow: View {
    @Binding var selected: TintPreset
    let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 6)
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "swatchpalette.fill")
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.accentColor.opacity(0.15)))
                    .foregroundStyle(Color.accentColor)
                Text("Presets")
                Spacer()
                Text(selected.label).font(.caption).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(TintPreset.allCases.filter { $0 != .custom }) { p in
                    Button { selected = p } label: {
                        LinearGradient(colors: [
                            Color(nsColor: NSColor(hex: p.hex) ?? .black),
                            Color(nsColor: NSColor(hex: p.hex2) ?? .black)
                        ], startPoint: .top, endPoint: .bottom)
                        .frame(height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(selected == p ? Color.accentColor : Color.white.opacity(0.1), lineWidth: selected == p ? 2 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

extension AppearanceSettings {
    func pickBackdropImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            settings.backdropImagePath = url.path
        }
    }
}

struct SliderRow: View {
    let icon: String
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let display: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.accentColor.opacity(0.15)))
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                    Spacer()
                    Text(display).font(.system(.callout, design: .monospaced)).foregroundStyle(.secondary)
                }
                Slider(value: $value, in: range)
            }
        }
    }
}

struct ColorPickerHex: View {
    let label: String
    @Binding var hex: String
    @State private var color: Color = .black
    var body: some View {
        HStack(spacing: 8) {
            if !label.isEmpty { Text(label) }
            ColorPicker("", selection: $color, supportsOpacity: false)
                .labelsHidden()
                .onAppear { color = Color(nsColor: NSColor(hex: hex) ?? .black) }
                .onChange(of: color) { _, newValue in
                    let ns = NSColor(newValue).usingColorSpace(.sRGB) ?? .black
                    let newHex = ns.toHex()
                    if newHex != hex { hex = newHex }
                }
                .onChange(of: hex) { _, newHex in
                    let ns = NSColor(hex: newHex) ?? .black
                    let c = Color(nsColor: ns)
                    if NSColor(c).toHex() != NSColor(color).toHex() { color = c }
                }
            Text(hex.uppercased()).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary).frame(width: 70, alignment: .trailing)
        }
    }
}
