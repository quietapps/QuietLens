import SwiftUI

struct LivePreview: View {
    @EnvironmentObject var settings: FocusLensSettings
    @Environment(\.colorScheme) var scheme

    @State private var breathScale: CGFloat = 1.0
    @State private var breathOpacity: CGFloat = 1.0
    @State private var driftX: CGFloat = 0
    @State private var driftY: CGFloat = 0

    private var tintColor: Color { Color(nsColor: settings.effectiveTintColor) }
    private var tintColor2: Color { Color(nsColor: settings.effectiveTintColor2) }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let blurAmount = settings.blurRadius * 0.30
            ZStack {
                // 1+2. Wallpaper + faux apps, BLURRED to match overlay blur
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(hex: "#FDA4AF") ?? .pink,
                            Color(hex: "#FCD34D") ?? .yellow,
                            Color(hex: "#6EE7B7") ?? .green,
                            Color(hex: "#93C5FD") ?? .blue
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    fauxApp(left: 0.06, top: 0.12, w: 120, h: 88, color: .white,
                            label: "Mail", mono: false, size: geo.size)
                    fauxApp(left: 0.36, top: 0.38, w: 180, h: 70,
                            color: Color(hex: "#1E293B") ?? .gray,
                            label: "Terminal", mono: true, size: geo.size)
                    fauxApp(left: 0.72, top: 0.14, w: 110, h: 84,
                            color: Color(hex: "#FEF3C7") ?? .yellow,
                            label: "Notes", mono: false, size: geo.size)
                    fauxApp(left: 0.14, top: 0.62, w: 140, h: 64,
                            color: Color(hex: "#DBEAFE") ?? .blue,
                            label: "Messages", mono: false, size: geo.size)
                }
                .blur(radius: blurAmount)
                .saturation(settings.grayscale ? 0 : 1)

                // 3. Tint / mode overlay on top of blurred bg
                overlayLayer
                    .opacity(Double(breathOpacity))
                    .scaleEffect(breathScale)
                    .offset(x: driftX, y: driftY)
                    .allowsHitTesting(false)

                // 4. Film grain
                if settings.grainIntensity > 0.01 {
                    Rectangle()
                        .fill(.white.opacity(0.05 + settings.grainIntensity * 0.18))
                        .blendMode(.overlay)
                        .allowsHitTesting(false)
                }

                // 5. Focused window
                focusedWindow(width: w * 0.44, height: h * 0.60)
                    .position(x: w * 0.30 + w * 0.44 / 2, y: h * 0.20 + h * 0.60 / 2)

                // 6. Live preview chip
                HStack(spacing: 4) {
                    Text("LIVE PREVIEW · \(settings.shaderMode.label.uppercased())")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.9)
                        .foregroundStyle(.white.opacity(0.92))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(.black.opacity(0.32)))
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(FL.C.edgeRing(scheme), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(scheme == .dark ? 0.4 : 0.15), radius: 18, y: 8)
        }
        .onAppear { applyShaderAnim() }
        .onChange(of: settings.shaderMode) { _, _ in applyShaderAnim() }
        .onChange(of: settings.animationSpeed) { _, _ in applyShaderAnim() }
    }

    // Reactive overlay layer — recomputes on every settings change
    @ViewBuilder
    private var overlayLayer: some View {
        let opacity = max(0.05, min(1.0, settings.overlayOpacity))

        if settings.overlayMode == .ambient {
            LinearGradient(
                colors: [tintColor.opacity(0), tintColor.opacity(opacity * 0.55)],
                startPoint: .top, endPoint: .bottom
            )
        } else if settings.gradientEnabled {
            LinearGradient(
                colors: [
                    tintColor.opacity(opacity * (settings.overlayMode == .tinted ? 1.0 : 0.85)),
                    tintColor2.opacity(opacity * (settings.overlayMode == .tinted ? 1.0 : 0.85))
                ],
                startPoint: gradStart, endPoint: gradEnd
            )
            .blendMode(settings.overlayMode == .tinted ? .multiply : .normal)
        } else {
            Rectangle()
                .fill(tintColor.opacity(opacity * (settings.overlayMode == .tinted ? 1.0 : 0.85)))
                .blendMode(settings.overlayMode == .tinted ? .multiply : .normal)
        }
    }

    private var gradStart: UnitPoint {
        let rad = settings.gradientAngle * .pi / 180
        return UnitPoint(x: 0.5 - 0.5 * cos(rad), y: 0.5 - 0.5 * sin(rad))
    }
    private var gradEnd: UnitPoint {
        let rad = settings.gradientAngle * .pi / 180
        return UnitPoint(x: 0.5 + 0.5 * cos(rad), y: 0.5 + 0.5 * sin(rad))
    }

    private func applyShaderAnim() {
        let speed = max(0.1, settings.animationSpeed)
        // Reset state
        withAnimation(.linear(duration: 0)) {
            breathScale = 1.0
            breathOpacity = 1.0
            driftX = 0
            driftY = 0
        }
        switch settings.shaderMode {
        case .staticMode:
            return
        case .breathing:
            withAnimation(.easeInOut(duration: 3.0 / speed).repeatForever(autoreverses: true)) {
                breathOpacity = 0.75
            }
        case .pulse:
            withAnimation(.easeInOut(duration: 1.4 / speed).repeatForever(autoreverses: true)) {
                breathScale = 1.02
            }
        case .drift:
            withAnimation(.easeInOut(duration: 7.0 / speed).repeatForever(autoreverses: true)) {
                driftX = 6
                driftY = -4
            }
        }
    }

    private func focusedWindow(width: CGFloat, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Circle().fill(Color(hex: "#FF5F57") ?? .red).frame(width: 8, height: 8)
                Circle().fill(Color(hex: "#FEBC2E") ?? .yellow).frame(width: 8, height: 8)
                Circle().fill(Color(hex: "#28C840") ?? .green).frame(width: 8, height: 8)
                Text("Safari · Focused")
                    .font(.system(size: 9))
                    .foregroundStyle(Color(white: 0.27))
                    .padding(.leading, 6)
                Spacer()
            }
            .padding(.horizontal, 8)
            .frame(height: 22)
            .overlay(alignment: .bottom) {
                Rectangle().fill(.black.opacity(0.08)).frame(height: 0.5)
            }
            VStack(alignment: .leading, spacing: 6) {
                Capsule().fill(Color(hex: "#E5E7EB") ?? .gray)
                    .frame(width: width * 0.60, height: 8)
                Capsule().fill(Color(hex: "#F1F5F9") ?? .gray)
                    .frame(width: width * 0.85, height: 6)
                Capsule().fill(Color(hex: "#F1F5F9") ?? .gray)
                    .frame(width: width * 0.70, height: 6)
                Capsule().fill(Color(hex: "#F1F5F9") ?? .gray)
                    .frame(width: width * 0.78, height: 6)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            Spacer(minLength: 0)
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: settings.edgeGlowEnabled ? tintColor.opacity(0.55) : .clear,
                radius: settings.edgeGlowEnabled ? max(8, settings.edgeGlowRadius * 0.8) : 0)
        .shadow(color: .black.opacity(0.25), radius: 12, y: 12)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.white.opacity(0.4), lineWidth: 1)
        )
    }

    private func fauxApp(left: CGFloat, top: CGFloat, w: CGFloat, h: CGFloat,
                         color: Color, label: String, mono: Bool, size: CGSize) -> some View {
        let textColor: Color = mono ? (Color(hex: "#94A3B8") ?? .gray) : (Color(hex: "#1E293B") ?? .gray)
        return VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: mono ? .regular : .medium, design: mono ? .monospaced : .default))
                .foregroundStyle(textColor)
                .opacity(0.75)
            Capsule().fill(textColor).opacity(0.22)
                .frame(width: w * 0.70, height: 4)
            Capsule().fill(textColor).opacity(0.16)
                .frame(width: w * 0.50, height: 4)
            Capsule().fill(textColor).opacity(0.16)
                .frame(width: w * 0.60, height: 4)
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(width: w, height: h, alignment: .topLeading)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 8).strokeBorder(.black.opacity(0.06), lineWidth: 0.5)
        )
        .position(x: size.width * left + w / 2, y: size.height * top + h / 2)
    }
}
