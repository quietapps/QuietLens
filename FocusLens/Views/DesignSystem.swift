import SwiftUI
import AppKit

enum FL {

    // MARK: Spacing (4px base scale)
    enum S {
        static let s1: CGFloat = 4
        static let s2: CGFloat = 8
        static let s3: CGFloat = 12
        static let s4: CGFloat = 16
        static let s5: CGFloat = 20
        static let s6: CGFloat = 24
        static let s7: CGFloat = 32
        static let s8: CGFloat = 40
        static let s9: CGFloat = 48
        static let s10: CGFloat = 64
    }

    // MARK: Radii
    enum R {
        static let control: CGFloat = 9
        static let cardSm: CGFloat = 12
        static let card: CGFloat = 18
        static let cardLg: CGFloat = 24
        static let window: CGFloat = 14
        static let pill: CGFloat = 999
    }

    // MARK: Typography
    enum T {
        static func display() -> Font { .system(size: 28, weight: .semibold) }
        static func title() -> Font { .system(size: 17, weight: .semibold) }
        static func body() -> Font { .system(size: 13, weight: .medium) }
        static func bodyR() -> Font { .system(size: 13, weight: .regular) }
        static func caption() -> Font { .system(size: 11, weight: .semibold) }
        static func mono() -> Font { .system(size: 12, weight: .medium, design: .monospaced) }
    }

    // MARK: Motion
    enum M {
        static let glass = Animation.timingCurve(0.32, 0.72, 0, 1, duration: 0.22)
        static let quick = Animation.timingCurve(0.4, 0, 0.2, 1, duration: 0.12)
        static let page = Animation.timingCurve(0.32, 0.72, 0, 1, duration: 0.36)
    }

    // MARK: Palette
    enum C {
        // Single shared accent. Default purple, overridable via settings.
        static var accent: Color { Color(hex: "#8B5CF6") ?? .purple }
        static var accentGlow: Color { Color(hex: "#8B5CF6")?.opacity(0.45) ?? .purple.opacity(0.45) }
        static var accentSoft: Color { Color(hex: "#8B5CF6")?.opacity(0.12) ?? .purple.opacity(0.12) }

        // Text
        static func text1(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.white.opacity(0.96) : Color.black.opacity(0.96)
        }
        static func text2(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.white.opacity(0.62) : Color.black.opacity(0.62)
        }
        static func text3(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.white.opacity(0.38) : Color.black.opacity(0.42)
        }

        // Glass fills
        static func chrome(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color(red: 28/255, green: 26/255, blue: 38/255).opacity(0.55) : Color.white.opacity(0.62)
        }
        static func panel(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.48)
        }
        static func control(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.70)
        }
        static func controlHover(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.white.opacity(0.14) : Color.white.opacity(0.92)
        }
        static func hairline(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)
        }
        static func edgeTop(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.white.opacity(0.16) : Color.white.opacity(0.95)
        }
        static func edgeRing(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06)
        }

        // Status
        static let green = Color(hex: "#26C485") ?? .green
        static let orange = Color(hex: "#FF9F0A") ?? .orange
        static let red = Color(hex: "#FF453A") ?? .red
        static let blue = Color(hex: "#2E7CF6") ?? .blue
    }
}

extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        let r = Double((v >> 16) & 0xff) / 255
        let g = Double((v >> 8) & 0xff) / 255
        let b = Double(v & 0xff) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}
