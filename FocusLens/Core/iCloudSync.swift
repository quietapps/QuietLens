import Foundation

@MainActor
final class iCloudSync {
    static let shared = iCloudSync()
    private let store = NSUbiquitousKeyValueStore.default
    private let defaults = UserDefaults.standard
    private var started = false
    private var suppressPush = false

    private let keys: [String] = [
        "overlayMode", "blurIntensity", "blurRadius", "overlayOpacity",
        "tintColorHex", "tintColor2Hex", "tintPreset", "useSystemTint",
        "gradientEnabled", "gradientAngle", "grainIntensity", "grayscale",
        "fadeDuration", "shaderMode", "animationSpeed",
        "shakeEnabled", "shakeSensitivity", "shakeModifier",
        "toggleShortcutKey", "toggleShortcutMods",
        "settingsShortcutKey", "settingsShortcutMods",
        "excludeAppShortcutKey", "excludeAppShortcutMods",
        "excludedBundleIDs", "pinnedBundleIDs",
        "highlightSameAppWindows", "autoHideDock", "autoHideMenuBar",
        "menuBarLeftClick", "launchAtLogin", "onboardingDismissed",
        "edgeGlowEnabled", "edgeGlowRadius",
        "backdropMode", "backdropImagePath"
    ]

    func start() {
        guard !started else { return }
        started = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(externalChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )
        store.synchronize()
        pullFromCloud()
    }

    func pushCurrent() {
        guard FocusLensSettings.shared.iCloudSyncEnabled else { return }
        guard !suppressPush else { return }
        for k in keys {
            if let v = defaults.object(forKey: k) {
                store.set(v, forKey: k)
            }
        }
        store.synchronize()
    }

    @objc private func externalChange(_ note: Notification) {
        Task { @MainActor in self.pullFromCloud() }
    }

    private func pullFromCloud() {
        guard FocusLensSettings.shared.iCloudSyncEnabled else { return }
        suppressPush = true
        var changed = false
        for k in keys {
            if let v = store.object(forKey: k) {
                let local = defaults.object(forKey: k)
                if !areEqual(local, v) {
                    defaults.set(v, forKey: k)
                    changed = true
                }
            }
        }
        if changed { FocusLensSettings.shared.reload() }
        suppressPush = false
    }

    private func areEqual(_ a: Any?, _ b: Any?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case let (l as NSObject, r as NSObject): return l.isEqual(r)
        default: return false
        }
    }
}
