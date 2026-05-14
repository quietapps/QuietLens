import AppKit
import Carbon.HIToolbox

@MainActor
final class HotkeyManager {
    var onToggle: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onToggleExclude: (() -> Void)?

    private let settings: FocusLensSettings
    private var toggleRef: EventHotKeyRef?
    private var settingsRef: EventHotKeyRef?
    private var excludeRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private static let toggleID: UInt32 = 1
    private static let settingsID: UInt32 = 2
    private static let excludeID: UInt32 = 3

    init(settings: FocusLensSettings) { self.settings = settings }

    func start() {
        installHandler()
        register()
        NotificationCenter.default.addObserver(forName: .focusLensShortcutChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.register() }
        }
    }

    private func installHandler() {
        guard eventHandlerRef == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let cb: EventHandlerUPP = { _, evt, _ in
            var hk = EventHotKeyID()
            GetEventParameter(evt, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hk)
            Task { @MainActor in
                switch hk.id {
                case HotkeyManager.toggleID: AppDelegate.shared?.hotkeyManager.onToggle?()
                case HotkeyManager.settingsID: AppDelegate.shared?.hotkeyManager.onOpenSettings?()
                case HotkeyManager.excludeID: AppDelegate.shared?.hotkeyManager.onToggleExclude?()
                default: break
                }
            }
            return noErr
        }
        InstallEventHandler(GetApplicationEventTarget(), cb, 1, &spec, nil, &eventHandlerRef)
    }

    private func register() {
        if let r = toggleRef { UnregisterEventHotKey(r); toggleRef = nil }
        if let r = settingsRef { UnregisterEventHotKey(r); settingsRef = nil }
        if let r = excludeRef { UnregisterEventHotKey(r); excludeRef = nil }
        if let key = settings.toggleShortcutKey {
            toggleRef = registerKey(keyCode: key, mods: settings.toggleShortcutMods, id: Self.toggleID)
        }
        if let key = settings.settingsShortcutKey {
            settingsRef = registerKey(keyCode: key, mods: settings.settingsShortcutMods, id: Self.settingsID)
        }
        if let key = settings.excludeAppShortcutKey {
            excludeRef = registerKey(keyCode: key, mods: settings.excludeAppShortcutMods, id: Self.excludeID)
        }
    }

    private func registerKey(keyCode: UInt16, mods: UInt, id: UInt32) -> EventHotKeyRef? {
        var ref: EventHotKeyRef?
        let hotID = EventHotKeyID(signature: OSType(0x464C4E53), id: id)
        RegisterEventHotKey(UInt32(keyCode), UInt32(mods), hotID, GetApplicationEventTarget(), 0, &ref)
        return ref
    }
}

extension Notification.Name {
    static let focusLensShortcutChanged = Notification.Name("focusLensShortcutChanged")
}
