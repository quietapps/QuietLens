import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var shared: AppDelegate!

    var statusItem: NSStatusItem!
    var overlayManager: OverlayManager!
    var windowTracker: WindowTracker!
    var shakeDetector: ShakeDetector!
    var hotkeyManager: HotkeyManager!
    var automationHandler: AutomationHandler!

    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        NSApp.setActivationPolicy(.accessory)

        let settings = FocusLensSettings.shared
        overlayManager = OverlayManager(settings: settings)
        windowTracker = WindowTracker()
        shakeDetector = ShakeDetector(settings: settings)
        hotkeyManager = HotkeyManager(settings: settings)
        automationHandler = AutomationHandler()

        setupStatusItem()
        setupBindings()
        setupURLHandler()

        windowTracker.onFocusedWindowChanged = { [weak self] info in
            self?.handleFocusChange(info)
        }
        shakeDetector.onShake = { [weak self] in self?.toggleOverlay() }
        shakeDetector.onPeekStart = { [weak self] in self?.overlayManager.peek(true) }
        shakeDetector.onPeekEnd = { [weak self] in self?.overlayManager.peek(false) }
        hotkeyManager.onToggle = { [weak self] in self?.toggleOverlay() }
        hotkeyManager.onOpenSettings = { [weak self] in self?.openSettings() }
        hotkeyManager.onToggleExclude = { [weak self] in self?.toggleExcludeCurrent() }

        evaluateAccessibility(promptIfMissing: false)
        startAccessibilityPoll()
    }

    private var trackingStarted = false
    private var axPollTimer: Timer?

    private var wasShowingOnboarding = false

    @MainActor
    private func evaluateAccessibility(promptIfMissing: Bool) {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: promptIfMissing] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(opts)
        if trusted {
            if !trackingStarted {
                trackingStarted = true
                startTracking()
            }
            onboardingWindow?.close()
        } else if !trackingStarted {
            wasShowingOnboarding = true
            showOnboarding()
        }
    }

    @MainActor
    private func startAccessibilityPoll() {
        axPollTimer?.invalidate()
        axPollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let trusted = AXIsProcessTrusted()
                if trusted && !self.trackingStarted {
                    self.trackingStarted = true
                    self.startTracking()
                    self.onboardingWindow?.close()
                    if self.wasShowingOnboarding {
                        self.wasShowingOnboarding = false
                        self.openSettings()
                    }
                } else if !trusted && self.trackingStarted {
                    self.trackingStarted = false
                    self.wasShowingOnboarding = true
                    self.showOnboarding()
                }
            }
        }
    }

    @MainActor
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = statusItem.button {
            btn.image = NSImage(systemSymbolName: "circle.lefthalf.filled", accessibilityDescription: "FocusLens")
            btn.image?.isTemplate = true
            btn.target = self
            btn.action = #selector(statusBarClicked(_:))
            btn.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        updateStatusIcon()
    }

    @MainActor
    private func setupBindings() {
        let s = FocusLensSettings.shared
        s.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.updateStatusIcon()
                self.overlayManager.refreshAppearance()
                self.overlayManager.refreshGeometry()
                self.windowTracker.refresh()
                self.applyAutoHide()
            }
            .store(in: &cancellables)
    }

    private func setupURLHandler() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURL(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc func handleURL(_ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor) {
        guard let str = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: str) else { return }
        Task { @MainActor in
            automationHandler.handle(url: url)
        }
    }

    @MainActor
    @objc private func statusBarClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showContextMenu()
        } else {
            switch FocusLensSettings.shared.menuBarLeftClick {
            case .toggleOverlay: toggleOverlay()
            case .openSettings: openSettings()
            }
        }
    }

    @MainActor
    private func showContextMenu() {
        let menu = NSMenu()
        let isOn = overlayManager.isEnabled
        menu.addItem(withTitle: isOn ? "Disable Overlay" : "Enable Overlay",
                     action: #selector(toggleFromMenu), keyEquivalent: "").target = self
        let focusName = windowTracker.currentApp?.localizedName ?? "—"
        let item = NSMenuItem(title: "Focused: \(focusName)", action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
        let exItem = NSMenuItem(title: isCurrentExcluded() ? "Include Current App" : "Exclude Current App",
                                action: #selector(toggleExcludeCurrent), keyEquivalent: "")
        exItem.target = self
        menu.addItem(exItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(openSettingsFromMenu), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit FocusLens", action: #selector(NSApp.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @MainActor @objc private func toggleFromMenu() { toggleOverlay() }
    @MainActor @objc private func openSettingsFromMenu() { openSettings() }
    @MainActor @objc func toggleExcludeCurrent() {
        guard let id = windowTracker.currentApp?.bundleIdentifier else { return }
        var list = FocusLensSettings.shared.excludedBundleIDs
        if let idx = list.firstIndex(of: id) { list.remove(at: idx) } else { list.append(id) }
        FocusLensSettings.shared.excludedBundleIDs = list
        applyCurrentExclusion()
    }

    @MainActor
    private func isCurrentExcluded() -> Bool {
        guard let id = windowTracker.currentApp?.bundleIdentifier else { return false }
        return FocusLensSettings.shared.excludedBundleIDs.contains(id)
    }

    @MainActor
    func toggleOverlay() {
        overlayManager.setEnabled(!overlayManager.isEnabled, animated: true)
        applyAutoHide()
        updateStatusIcon()
    }

    @MainActor
    func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView().environmentObject(FocusLensSettings.shared)
            let host = NSHostingController(rootView: view)
            let w = NSWindow(contentViewController: host)
            w.title = "FocusLens Settings"
            w.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            w.titlebarAppearsTransparent = true
            w.setContentSize(NSSize(width: 760, height: 560))
            w.center()
            w.isReleasedWhenClosed = false
            settingsWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @MainActor
    func showOnboarding() {
        if onboardingWindow == nil {
            let v = OnboardingView(onDone: { [weak self] in
                guard let self else { return }
                self.onboardingWindow?.close()
                if !self.trackingStarted {
                    self.trackingStarted = true
                    self.startTracking()
                }
                if self.wasShowingOnboarding {
                    self.wasShowingOnboarding = false
                    self.openSettings()
                }
            })
            let host = NSHostingController(rootView: v)
            let w = NSWindow(contentViewController: host)
            w.title = "Welcome to FocusLens"
            w.styleMask = [.titled, .closable]
            w.setContentSize(NSSize(width: 520, height: 400))
            w.center()
            w.isReleasedWhenClosed = false
            onboardingWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow?.makeKeyAndOrderFront(nil)
    }

    @MainActor
    private func startTracking() {
        windowTracker.start()
        shakeDetector.start()
        hotkeyManager.start()
    }

    @MainActor
    private func handleFocusChange(_ info: FocusedWindowInfo?) {
        applyCurrentExclusion()
        overlayManager.updateFocus(info, animated: true)
        updateStatusIcon()
    }

    @MainActor
    private func applyCurrentExclusion() {
        let excluded = isCurrentExcluded()
        overlayManager.setExcluded(excluded, animated: true)
        applyAutoHide()
    }

    @MainActor
    private func applyAutoHide() {
        let s = FocusLensSettings.shared
        let active = overlayManager.isEnabled && overlayManager.isVisible
        var opts: NSApplication.PresentationOptions = []
        if active && s.autoHideDock { opts.insert(.autoHideDock) }
        if active && s.autoHideMenuBar { opts.insert(.autoHideMenuBar) }
        NSApp.presentationOptions = opts
    }

    @MainActor
    private func updateStatusIcon() {
        guard let btn = statusItem?.button else { return }
        let isOn = overlayManager?.isEnabled ?? false
        let excluded = isCurrentExcluded()
        let ambient = FocusLensSettings.shared.overlayMode == .ambient
        let name: String
        if excluded {
            name = "circle.dashed"
        } else if isOn && ambient {
            name = "circle.righthalf.filled"
        } else if isOn {
            name = "circle.lefthalf.filled"
        } else {
            name = "circle"
        }
        btn.image = NSImage(systemSymbolName: name, accessibilityDescription: "FocusLens")
        btn.image?.isTemplate = true
    }
}
