import Foundation

@MainActor
final class iCloudSync {
    static let shared = iCloudSync()
    // Only instantiate the KVS once we actually need it. Touching
    // NSUbiquitousKeyValueStore.default without the
    // `com.apple.developer.ubiquity-kvstore-identifier` entitlement (this
    // build is unsigned) emits a noisy "BUG IN CLIENT OF KVS" warning and
    // does nothing useful. Lazy + gated by the user toggle.
    private var _store: NSUbiquitousKeyValueStore?
    private var storeAttempted = false
    private var store: NSUbiquitousKeyValueStore? {
        if storeAttempted { return _store }
        storeAttempted = true
        // Don't touch NSUbiquitousKeyValueStore.default unless the build
        // actually has the ubiquity-kvstore entitlement AND the user has
        // opted in. Otherwise AppKit logs:
        //   "BUG IN CLIENT OF KVS: Trying to initialize
        //    NSUbiquitousKeyValueStore without a store identifier."
        guard QuietLensSettings.shared.iCloudSyncEnabled,
              iCloudSync.hasEntitlement else { return nil }
        _store = NSUbiquitousKeyValueStore.default
        return _store
    }
    private let defaults = UserDefaults.standard
    private var started = false
    private var suppressPush = false

    private static let hasEntitlement: Bool = {
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        let key = "com.apple.developer.ubiquity-kvstore-identifier" as CFString
        return SecTaskCopyValueForEntitlement(task, key, nil) != nil
    }()

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
        guard let store else { return }
        NotificationCenter.default.addObserver(
            self, selector: #selector(externalChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )
        store.synchronize()
        pullFromCloud()
    }

    func pushCurrent() {
        guard QuietLensSettings.shared.iCloudSyncEnabled else { return }
        guard !suppressPush else { return }
        guard let store else { return }
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
        guard QuietLensSettings.shared.iCloudSyncEnabled else { return }
        guard let store else { return }
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
        if changed { QuietLensSettings.shared.reload() }
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
