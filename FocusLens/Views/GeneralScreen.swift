import SwiftUI

struct GeneralScreen: View {
    @EnvironmentObject var settings: FocusLensSettings
    var search: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeader("General",
                       subtitle: "How FocusLens starts up and lives in your menu bar.")

            if !settings.onboardingDismissed {
                Callout(
                    title: "New to FocusLens?",
                    message: "Set a hotkey in Gestures, then add apps to Rules → Exclude so they stay clear while you work.",
                    systemImage: "sparkles",
                    trailing: AnyView(
                        GhostButton(title: "Got it") { settings.onboardingDismissed = true }
                    )
                )
                .padding(.bottom, FL.S.s5)
            }

            if match("startup launch login auto enable focus") {
                SectionLabel(text: "Startup")
                GlassPanel {
                    SettingsRow(icon: "power",
                                title: "Launch at Login",
                                subtitle: "Open FocusLens automatically when you sign in.",
                                isFirst: true,
                                trailing: { GlassSwitch(isOn: $settings.launchAtLogin) })

                    SettingsRow(icon: "bolt",
                                title: "Auto-enable on focus",
                                subtitle: "Turn the overlay on the moment you click into any window.",
                                comingSoon: true,
                                trailing: { GlassSwitch(isOn: .constant(false)) })
                }
            }

            if match("menu bar click action indicator dot") {
                SectionLabel(text: "Menu Bar")
                GlassPanel {
                    SettingsRow(icon: "menubar.rectangle",
                                title: "Menu Icon click action",
                                subtitle: "What happens when you click the menu bar icon.",
                                isFirst: true,
                                trailing: {
                        GlassSegmented(selection: $settings.menuBarLeftClick,
                                       items: MenuBarLeftClickAction.allCases,
                                       label: { $0.label })
                    })

                    SettingsRow(icon: "circle.fill",
                                title: "Show indicator dot",
                                subtitle: "Live state on the menu bar icon when the overlay is active.",
                                trailing: { GlassSwitch(isOn: $settings.showIndicatorDot) })
                }
            }

            if match("icloud sync settings cross") {
                SectionLabel(text: "Sync")
                GlassPanel {
                    SettingsRow(icon: "icloud",
                                title: "iCloud Settings Sync",
                                subtitle: "Mirror your overlay configuration across Macs.",
                                isFirst: true,
                                comingSoon: true,
                                trailing: { GlassSwitch(isOn: .constant(false)) })
                }
            }

            if match("appearance theme color scheme dark light") {
                SectionLabel(text: "Appearance")
                GlassPanel {
                    SettingsRow(icon: "sun.max",
                                title: "Color Scheme",
                                subtitle: "Override the system appearance for this app.",
                                isFirst: true,
                                trailing: {
                        GlassSegmented(selection: $settings.colorSchemePref,
                                       items: ColorSchemePref.allCases,
                                       label: { $0.label })
                    })
                }
            }

            if match("updates check version") {
                SectionLabel(text: "Updates")
                GlassPanel {
                    SettingsRow(icon: "arrow.down.circle",
                                title: "Check for Updates",
                                subtitle: "You're on version 1.0.2.",
                                isFirst: true,
                                comingSoon: true,
                                trailing: { GhostButton(title: "Check now") {} })
                }
            }
        }
    }

    private func match(_ keywords: String) -> Bool {
        guard !search.isEmpty else { return true }
        return keywords.lowercased().contains(search.lowercased())
    }
}
