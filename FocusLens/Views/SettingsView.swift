import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var settings: FocusLensSettings
    @State private var selectedTab: SettingsTab = .general
    @State private var searchText: String = ""
    @FocusState private var searchFocused: Bool

    enum SettingsTab: String, CaseIterable, Identifiable {
        case general, appearance, gestures, rules, about
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .appearance: return "paintbrush"
            case .gestures: return "hand.draw"
            case .rules: return "list.bullet.rectangle"
            case .about: return "info.circle"
            }
        }
        var shortcut: KeyEquivalent {
            switch self {
            case .general: return "1"
            case .appearance: return "2"
            case .gestures: return "3"
            case .rules: return "4"
            case .about: return "5"
            }
        }
    }

    var body: some View {
        ZStack {
            WallpaperBackground()
            HStack(spacing: 0) {
                sidebar
                content
            }
        }
        .preferredColorScheme(preferredScheme)
        .frame(minWidth: 920, minHeight: 640)
        .background(KeyboardShortcutsCatcher(
            onTab: { i in
                let all = SettingsTab.allCases
                if i >= 0 && i < all.count { withAnimation(FL.M.glass) { selectedTab = all[i] } }
            },
            onSearch: { searchFocused = true }
        ))
    }

    private var preferredScheme: ColorScheme? {
        switch settings.colorSchemePref {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    // MARK: - Sidebar (floating glass)
    @Environment(\.colorScheme) var scheme

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: FL.S.s2) {
            // Brand block
            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable().interpolation(.high)
                    .frame(width: 30, height: 30)
                VStack(alignment: .leading, spacing: 4) {
                    Text("FocusLens")
                        .font(.system(size: 16, weight: .semibold))
                        .tracking(-0.16)
                    Text("1.0.2")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(0.6)
                        .foregroundStyle(FL.C.text3(scheme))
                        .textCase(.uppercase)
                }
                Spacer()
            }
            .padding(.horizontal, FL.S.s3)
            .padding(.top, FL.S.s3)
            .padding(.bottom, FL.S.s5)

            // Nav items
            ForEach(SettingsTab.allCases) { tab in
                sidebarItem(tab)
            }

            Spacer()

            // Search at bottom
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(FL.C.text2(scheme))
                    .frame(width: 22, height: 22)
                TextField("Search…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(FL.T.body())
                    .focused($searchFocused)
                Text("⌘K")
                    .font(FL.T.mono())
                    .tracking(0.04)
                    .foregroundStyle(FL.C.text3(scheme))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
        }
        .padding(FL.S.s3)
        .frame(width: 220)
        .background(
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Rectangle().fill(scheme == .dark ? Color.white.opacity(0.04) : Color.white.opacity(0.12))
            }
            .clipShape(RoundedRectangle(cornerRadius: FL.R.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FL.R.card, style: .continuous)
                    .strokeBorder(FL.C.edgeRing(scheme), lineWidth: 0.5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: FL.R.card, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [FL.C.edgeTop(scheme), .clear],
                                       startPoint: .top, endPoint: .center),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(scheme == .dark ? 0.40 : 0.14), radius: 22, y: 10)
        )
        .padding(FL.S.s2)
    }

    private func sidebarItem(_ tab: SettingsTab) -> some View {
        let isSel = selectedTab == tab
        return Button {
            withAnimation(FL.M.glass) { selectedTab = tab }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: tab.icon)
                    .frame(width: 22, height: 22)
                    .foregroundStyle(isSel ? FL.C.accent : FL.C.text2(scheme))
                Text(tab.label)
                    .font(FL.T.body())
                    .foregroundStyle(isSel ? FL.C.text1(scheme) : FL.C.text2(scheme))
                Spacer()
                Text("⌘\(tab.shortcut.character)")
                    .font(FL.T.mono())
                    .tracking(0.04)
                    .foregroundStyle(FL.C.text3(scheme))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                ZStack {
                    if isSel {
                        RoundedRectangle(cornerRadius: 9).fill(.ultraThinMaterial)
                        RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(scheme == .dark ? 0.08 : 0.40))
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(isSel ? FL.C.edgeTop(scheme).opacity(0.5) : .clear, lineWidth: 0.5)
            )
            .shadow(color: isSel ? .black.opacity(0.08) : .clear, radius: 3, y: 1)
            .contentShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(tab.shortcut, modifiers: .command)
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Group {
                    switch selectedTab {
                    case .general: GeneralScreen(search: searchText)
                    case .appearance: AppearanceScreen(search: searchText)
                    case .gestures: GestureScreen(search: searchText)
                    case .rules: RulesScreen(search: searchText)
                    case .about: AboutScreen()
                    }
                }
            }
            .padding(.horizontal, FL.S.s7)
            .padding(.top, FL.S.s6)
            .padding(.bottom, FL.S.s7)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct KeyboardShortcutsCatcher: NSViewRepresentable {
    let onTab: (Int) -> Void
    let onSearch: () -> Void
    func makeNSView(context: Context) -> NSView {
        let v = CatcherView()
        v.onTab = onTab
        v.onSearch = onSearch
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
    final class CatcherView: NSView {
        var onTab: ((Int) -> Void)?
        var onSearch: (() -> Void)?
        private var monitor: Any?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if monitor == nil {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                    guard let self else { return event }
                    if event.modifierFlags.contains(.command), let ch = event.charactersIgnoringModifiers {
                        if let n = Int(ch), n >= 1 && n <= 5 {
                            self.onTab?(n - 1); return nil
                        }
                        if ch == "k" || ch == "K" { self.onSearch?(); return nil }
                    }
                    return event
                }
            }
        }
        deinit { if let m = monitor { NSEvent.removeMonitor(m) } }
    }
}
