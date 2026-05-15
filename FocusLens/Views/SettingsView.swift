import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: FocusLensSettings
    @State private var selectedTab: SettingsTab = .appearance

    enum SettingsTab: String, CaseIterable, Identifiable {
        case general, appearance, gestures, rules, about
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var icon: String {
            switch self {
            case .general: return "gearshape.fill"
            case .appearance: return "paintbrush.fill"
            case .gestures: return "hand.tap.fill"
            case .rules: return "list.bullet.rectangle.fill"
            case .about: return "info.circle.fill"
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            content
        }
        .frame(minWidth: 720, minHeight: 520)
        .background(VisualEffectBackground().ignoresSafeArea())
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "circle.lefthalf.filled").font(.system(size: 22, weight: .semibold))
                Text("FocusLens").font(.system(size: 17, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.top, 18)
            .padding(.bottom, 18)

            ForEach(SettingsTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: tab.icon).frame(width: 22)
                        Text(tab.label)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedTab == tab ? Color.accentColor.opacity(0.18) : .clear)
                    )
                    .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.primary)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(8)
        .frame(width: 200)
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(selectedTab.label).font(.system(size: 22, weight: .bold))
                    .padding(.bottom, 4)
                switch selectedTab {
                case .general: GeneralSettings()
                case .appearance: AppearanceSettings()
                case .gestures: GestureSettings()
                case .rules: RulesSettings()
                case .about: AboutView()
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .sidebar
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct CCCard<Content: View>: View {
    let title: String?
    @ViewBuilder var content: Content
    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title { Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary).textCase(.uppercase) }
            VStack(alignment: .leading, spacing: 10) { content }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.regularMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                )
        }
    }
}

struct CCRow<Trailing: View>: View {
    let icon: String?
    let title: String
    let subtitle: String?
    @ViewBuilder var trailing: Trailing
    init(icon: String? = nil, title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.icon = icon; self.title = title; self.subtitle = subtitle; self.trailing = trailing()
    }
    var body: some View {
        HStack(spacing: 10) {
            if let icon {
                Image(systemName: icon)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.accentColor.opacity(0.15)))
                    .foregroundStyle(Color.accentColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer()
            trailing
        }
    }
}

struct GeneralSettings: View {
    @EnvironmentObject var settings: FocusLensSettings
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !settings.onboardingDismissed {
                OnboardingTile()
            }
            CCCard("Startup") {
                CCRow(icon: "power", title: "Launch at Login") {
                    Toggle("", isOn: $settings.launchAtLogin).labelsHidden()
                }
            }
            CCCard("Menu Bar") {
                CCRow(icon: "menubar.rectangle", title: "Left-click action") {
                    Picker("", selection: $settings.menuBarLeftClick) {
                        ForEach(MenuBarLeftClickAction.allCases) { Text($0.label).tag($0) }
                    }.labelsHidden().frame(width: 180)
                }
            }
            CCCard("Sync") {
                CCRow(icon: "icloud", title: "iCloud Settings Sync",
                      subtitle: "Mirror your overlay configuration across Macs") {
                    Toggle("", isOn: $settings.iCloudSyncEnabled).labelsHidden()
                }
            }
            CCCard("Updates") {
                CCRow(icon: "arrow.down.circle", title: "Check for Updates", subtitle: "Coming soon") {
                    Button("Check") {}
                }
            }
        }
    }
}

struct OnboardingTile: View {
    @EnvironmentObject var settings: FocusLensSettings
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 28, weight: .semibold))
                    .frame(width: 56, height: 56)
                    .background(
                        LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.6)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome to FocusLens").font(.system(size: 18, weight: .bold))
                    Text("Dim everything except your active window. Just shake your cursor when the screen gets loud.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
            }
            VStack(alignment: .leading, spacing: 8) {
                tipRow(icon: "circle.lefthalf.filled", title: "Click menu bar icon", subtitle: "Toggle the overlay on or off")
                tipRow(icon: "wave.3.right", title: "Shake to toggle", subtitle: "Wiggle your cursor in any direction")
                tipRow(icon: "keyboard", title: "Global shortcut", subtitle: "Set a hotkey in Gestures")
                tipRow(icon: "rectangle.dashed", title: "Exclude apps", subtitle: "Auto-disable for apps in your list")
            }
            HStack {
                Spacer()
                Button("Got it") { settings.onboardingDismissed = true }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(LinearGradient(colors: [Color.accentColor.opacity(0.4), Color.accentColor.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
    }

    private func tipRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.accentColor.opacity(0.15)))
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.callout)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

struct AboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            CCCard {
                VStack(spacing: 12) {
                    Image(systemName: "circle.lefthalf.filled").font(.system(size: 64))
                    Text("FocusLens").font(.system(size: 22, weight: .bold))
                    Text("Version 1.0.1").foregroundStyle(.secondary)
                    Text("Free and open source under the MIT License.")
                        .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            CCCard("Links") {
                CCRow(icon: "globe", title: "Website") {
                    Link("Open", destination: URL(string: "https://github.com/parththummar/FocusLens")!)
                }
                Divider()
                CCRow(icon: "doc.text", title: "License") {
                    Link("MIT", destination: URL(string: "https://opensource.org/licenses/MIT")!)
                }
                Divider()
                CCRow(icon: "ladybug", title: "Report Issue") {
                    Link("GitHub", destination: URL(string: "https://github.com/parththummar/FocusLens/issues")!)
                }
            }
            CCCard("Credits") {
                Text("Inspired by Monocle. Built with Swift, SwiftUI, and AppKit.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}
