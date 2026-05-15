import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct RulesSettings: View {
    @EnvironmentObject var settings: FocusLensSettings
    @State private var selection: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            CCCard("Excluded Apps") {
                if settings.excludedBundleIDs.isEmpty {
                    Text("No apps excluded. Excluded apps disable the overlay automatically.")
                        .font(.callout).foregroundStyle(.secondary)
                } else {
                    ForEach(settings.excludedBundleIDs, id: \.self) { bid in
                        let app = ExcludedApp(bundleID: bid)
                        HStack(spacing: 10) {
                            Image(nsImage: app.icon).resizable().frame(width: 22, height: 22)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(app.name)
                                Text(bid).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                settings.excludedBundleIDs.removeAll { $0 == bid }
                            } label: {
                                Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        if bid != settings.excludedBundleIDs.last { Divider() }
                    }
                }
                Divider()
                HStack {
                    Button {
                        addAppViaPicker()
                    } label: {
                        Label("Add App", systemImage: "plus")
                    }
                    Menu("From Running") {
                        ForEach(runningApps(), id: \.bundleIdentifier) { app in
                            Button(app.localizedName ?? app.bundleIdentifier ?? "?") {
                                if let id = app.bundleIdentifier, !settings.excludedBundleIDs.contains(id) {
                                    settings.excludedBundleIDs.append(id)
                                }
                            }
                        }
                    }
                    Spacer()
                }
            }
            CCCard("Pinned Apps") {
                if settings.pinnedBundleIDs.isEmpty {
                    Text("Pinned apps always stay clear, even when not focused. Useful for keeping a terminal or music player visible.")
                        .font(.callout).foregroundStyle(.secondary)
                } else {
                    ForEach(settings.pinnedBundleIDs, id: \.self) { bid in
                        let app = ExcludedApp(bundleID: bid)
                        HStack(spacing: 10) {
                            Image(nsImage: app.icon).resizable().frame(width: 22, height: 22)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(app.name)
                                Text(bid).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                settings.pinnedBundleIDs.removeAll { $0 == bid }
                            } label: {
                                Image(systemName: "pin.slash.fill").foregroundStyle(.orange)
                            }
                            .buttonStyle(.plain)
                        }
                        if bid != settings.pinnedBundleIDs.last { Divider() }
                    }
                }
                Divider()
                HStack {
                    Button {
                        addPinnedViaPicker()
                    } label: {
                        Label("Pin App", systemImage: "pin")
                    }
                    Menu("From Running") {
                        ForEach(runningApps(), id: \.bundleIdentifier) { app in
                            Button(app.localizedName ?? app.bundleIdentifier ?? "?") {
                                if let id = app.bundleIdentifier, !settings.pinnedBundleIDs.contains(id) {
                                    settings.pinnedBundleIDs.append(id)
                                }
                            }
                        }
                    }
                    Spacer()
                }
            }
            CCCard("Behavior") {
                CCRow(icon: "rectangle.stack.fill", title: "Highlight all windows of same app") {
                    Toggle("", isOn: $settings.highlightSameAppWindows).labelsHidden()
                }
                Divider()
                CCRow(icon: "dock.rectangle", title: "Hide Dock") {
                    Toggle("", isOn: $settings.autoHideDock).labelsHidden()
                }
                Divider()
                CCRow(icon: "menubar.rectangle", title: "Hide Menu Bar") {
                    Toggle("", isOn: $settings.autoHideMenuBar).labelsHidden()
                }
            }
        }
    }

    private func runningApps() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    private func addPinnedViaPicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url,
           let bid = Bundle(url: url)?.bundleIdentifier,
           !settings.pinnedBundleIDs.contains(bid) {
            settings.pinnedBundleIDs.append(bid)
        }
    }

    private func addAppViaPicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url,
           let bid = Bundle(url: url)?.bundleIdentifier,
           !settings.excludedBundleIDs.contains(bid) {
            settings.excludedBundleIDs.append(bid)
        }
    }
}
