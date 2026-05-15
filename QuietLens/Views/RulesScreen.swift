import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct RulesScreen: View {
    @EnvironmentObject var settings: QuietLensSettings
    @Environment(\.colorScheme) var scheme
    var search: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeader("Rules", subtitle: "Per-app behavior and automatic states.")

            if match("exclude excluded apps disable") {
                SectionLabel(text: "Excluded Apps")
                Text("Stay dim even when focused")
                    .font(FL.T.bodyR()).foregroundStyle(FL.C.text2(scheme))
                    .padding(.horizontal, FL.S.s2).padding(.bottom, FL.S.s2)

                GlassPanel {
                    if filteredExcluded.isEmpty {
                        emptyText("No apps excluded. Add one below.")
                    } else {
                        ForEach(Array(filteredExcluded.enumerated()), id: \.element) { idx, bid in
                            AppRow(bundleID: bid, isFirst: idx == 0) {
                                settings.excludedBundleIDs.removeAll { $0 == bid }
                            }
                        }
                    }
                    addRow(addAction: { addApp(into: \.excludedBundleIDs) },
                           addTitle: "Add app",
                           addIcon: "plus",
                           menuTitle: "From Running") {
                        ForEach(runningApps(), id: \.bundleIdentifier) { app in
                            Button(app.localizedName ?? app.bundleIdentifier ?? "?") {
                                if let id = app.bundleIdentifier, !settings.excludedBundleIDs.contains(id) {
                                    settings.excludedBundleIDs.append(id)
                                }
                            }
                        }
                    }
                }
            }

            if match("pin pinned apps clear") {
                SectionLabel(text: "Pinned Apps")
                Text("Always stay clear, even unfocused")
                    .font(FL.T.bodyR()).foregroundStyle(FL.C.text2(scheme))
                    .padding(.horizontal, FL.S.s2).padding(.bottom, FL.S.s2)

                GlassPanel {
                    if filteredPinned.isEmpty {
                        emptyText("No pinned apps yet. Pin a terminal or music player.")
                    } else {
                        ForEach(Array(filteredPinned.enumerated()), id: \.element) { idx, bid in
                            AppRow(bundleID: bid, isFirst: idx == 0) {
                                settings.pinnedBundleIDs.removeAll { $0 == bid }
                            }
                        }
                    }
                    addRow(addAction: { addApp(into: \.pinnedBundleIDs) },
                           addTitle: "Pin app",
                           addIcon: "pin",
                           menuTitle: "From Running") {
                        ForEach(runningApps(), id: \.bundleIdentifier) { app in
                            Button(app.localizedName ?? app.bundleIdentifier ?? "?") {
                                if let id = app.bundleIdentifier, !settings.pinnedBundleIDs.contains(id) {
                                    settings.pinnedBundleIDs.append(id)
                                }
                            }
                        }
                    }
                }
            }

            if match("behavior dock menu bar highlight auto disable") {
                SectionLabel(text: "Behavior")
                GlassPanel {
                    SettingsRow(icon: "rectangle.stack",
                                title: "Highlight all windows of same app",
                                isFirst: true,
                                trailing: { GlassSwitch(isOn: $settings.highlightSameAppWindows) })
                    SettingsRow(icon: "dock.rectangle", title: "Hide Dock while focused",
                                trailing: { GlassSwitch(isOn: $settings.autoHideDock) })
                    SettingsRow(icon: "menubar.rectangle", title: "Hide menu bar while focused",
                                trailing: { GlassSwitch(isOn: $settings.autoHideMenuBar) })
                    SettingsRow(icon: "timer", title: "Auto-disable after",
                                subtitle: "Turn the overlay off after this idle period.",
                                comingSoon: true,
                                trailing: {
                        GlassPicker(selection: $settings.autoDisableAfter,
                                    items: AutoDisableAfter.allCases,
                                    label: { $0.label })
                    })
                }
            }
        }
    }

    @ViewBuilder
    private func addRow<MenuContent: View>(addAction: @escaping () -> Void,
                                           addTitle: String,
                                           addIcon: String,
                                           menuTitle: String,
                                           @ViewBuilder menu: () -> MenuContent) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Color.clear.frame(width: 56)
                Rectangle().fill(FL.C.hairline(scheme)).frame(height: 0.5)
            }
            HStack(spacing: 10) {
                GhostButton(title: addTitle, icon: addIcon, action: addAction)
                Menu(content: menu) {
                    HStack(spacing: 6) {
                        Text(menuTitle).font(FL.T.body())
                        VStack(spacing: 0) {
                            Image(systemName: "chevron.up").font(.system(size: 7, weight: .bold))
                            Image(systemName: "chevron.down").font(.system(size: 7, weight: .bold))
                        }
                        .foregroundStyle(FL.C.text3(scheme))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: FL.R.control).fill(FL.C.control(scheme))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: FL.R.control).strokeBorder(FL.C.edgeRing(scheme), lineWidth: 0.5)
                    )
                    .foregroundStyle(FL.C.text1(scheme))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                Spacer()
            }
            .padding(.horizontal, FL.S.s4)
            .padding(.vertical, FL.S.s3)
        }
    }

    private var filteredExcluded: [String] {
        guard !search.isEmpty else { return settings.excludedBundleIDs }
        return settings.excludedBundleIDs.filter { $0.lowercased().contains(search.lowercased()) }
    }
    private var filteredPinned: [String] {
        guard !search.isEmpty else { return settings.pinnedBundleIDs }
        return settings.pinnedBundleIDs.filter { $0.lowercased().contains(search.lowercased()) }
    }

    private func emptyText(_ text: String) -> some View {
        Text(text).font(FL.T.bodyR()).foregroundStyle(FL.C.text2(scheme))
            .padding(FL.S.s4)
    }

    private func runningApps() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    private func addApp(into keyPath: ReferenceWritableKeyPath<QuietLensSettings, [String]>) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        if panel.runModal() == .OK, let url = panel.url,
           let bid = Bundle(url: url)?.bundleIdentifier,
           !settings[keyPath: keyPath].contains(bid) {
            settings[keyPath: keyPath].append(bid)
        }
    }

    private func match(_ keywords: String) -> Bool {
        guard !search.isEmpty else { return true }
        return keywords.lowercased().contains(search.lowercased())
    }
}

struct AppRow: View {
    let bundleID: String
    let isFirst: Bool
    let onRemove: () -> Void
    @Environment(\.colorScheme) var scheme

    var body: some View {
        let app = ExcludedApp(bundleID: bundleID)
        VStack(spacing: 0) {
            if !isFirst {
                HStack(spacing: 0) {
                    Color.clear.frame(width: 56)
                    Rectangle().fill(FL.C.hairline(scheme)).frame(height: 0.5)
                }
            }
            HStack(spacing: FL.S.s3) {
                Image(nsImage: app.icon)
                    .resizable()
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7).strokeBorder(FL.C.edgeRing(scheme), lineWidth: 0.5)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name).font(FL.T.title()).foregroundStyle(FL.C.text1(scheme))
                    Text(bundleID).font(FL.T.mono()).foregroundStyle(FL.C.text2(scheme))
                }
                Spacer(minLength: FL.S.s3)
                DangerCircleButton(icon: "minus", action: onRemove)
            }
            .padding(.horizontal, FL.S.s4)
            .padding(.vertical, FL.S.s3)
            .frame(minHeight: 52)
        }
    }
}
