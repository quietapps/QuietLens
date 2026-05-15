import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, @unchecked Sendable {
    @MainActor func applicationWillTerminate(_ notification: Notification) {
        WindowRaiser.shared.clearAll()
    }

    // Settings/Onboarding stay at .normal level. Putting them above the
    // overlay (screenSaver+1) used to keep them visible while the overlay was
    // on, but it broke macOS Screenshot which then can't capture them.
    // OverlayManager now treats our own windows as cutout targets, so they
    // stay clear without needing a higher window level.

    @MainActor
    func windowDidBecomeKey(_ notification: Notification) {}

    @MainActor
    func windowDidResignKey(_ notification: Notification) {}

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

        let settings = QuietLensSettings.shared
        overlayManager = OverlayManager(settings: settings)
        windowTracker = WindowTracker()
        shakeDetector = ShakeDetector(settings: settings)
        hotkeyManager = HotkeyManager(settings: settings)
        automationHandler = AutomationHandler()

        setupStatusItem()
        setupBindings()
        setupURLHandler()
        iCloudSync.shared.start()

        windowTracker.onFocusedWindowChanged = { [weak self] info in
            self?.handleFocusChange(info)
        }
        shakeDetector.onShake = { [weak self] in self?.toggleOverlay() }
        shakeDetector.onPeekStart = { [weak self] in self?.overlayManager.peek(true) }
        shakeDetector.onPeekEnd = { [weak self] in self?.overlayManager.peek(false) }
        hotkeyManager.onToggle = { [weak self] in self?.toggleOverlay() }
        hotkeyManager.onOpenSettings = { [weak self] in self?.openSettings() }
        hotkeyManager.onToggleExclude = { [weak self] in self?.toggleExcludeCurrent() }
        hotkeyManager.onTogglePin = { [weak self] in self?.togglePinCurrent() }

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
            btn.image = NSImage(systemSymbolName: "circle.lefthalf.filled", accessibilityDescription: "Quiet Lens")
            btn.image?.isTemplate = true
            btn.target = self
            btn.action = #selector(statusBarClicked(_:))
            btn.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        updateStatusIcon()
    }

    @MainActor
    private func setupBindings() {
        let s = QuietLensSettings.shared
        s.objectWillChange
            .debounce(for: .milliseconds(60), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.updateStatusIcon()
                self.overlayManager.refreshAppearance()
                self.overlayManager.refreshGeometry()
                self.windowTracker.refresh()
                self.applyAutoHide()
                iCloudSync.shared.pushCurrent()
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
            switch QuietLensSettings.shared.menuBarLeftClick {
            case .toggleOverlay: toggleOverlay()
            case .openSettings: openSettings()
            }
        }
    }

    @MainActor
    private func showContextMenu() {
        let menu = NSMenu()
        let isOn = overlayManager.isEnabled
        let toggleItem = NSMenuItem(title: isOn ? "Disable Overlay" : "Enable Overlay",
                                    action: #selector(toggleFromMenu), keyEquivalent: "")
        toggleItem.image = NSImage(systemSymbolName: isOn ? "pause.circle" : "play.circle",
                                   accessibilityDescription: nil)
        toggleItem.target = self
        menu.addItem(toggleItem)

        let focusName = windowTracker.currentApp?.localizedName ?? "—"
        let focusItem = NSMenuItem(title: "Focused: \(focusName)", action: nil, keyEquivalent: "")
        focusItem.image = NSImage(systemSymbolName: "macwindow", accessibilityDescription: nil)
        focusItem.isEnabled = false
        menu.addItem(focusItem)

        let excluded = isCurrentExcluded()
        let exItem = NSMenuItem(title: excluded ? "Include Current App" : "Exclude Current App",
                                action: #selector(toggleExcludeCurrent), keyEquivalent: "")
        exItem.image = NSImage(systemSymbolName: excluded ? "plus.circle" : "minus.circle",
                               accessibilityDescription: nil)
        exItem.target = self
        menu.addItem(exItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…",
                                      action: #selector(openSettingsFromMenu), keyEquivalent: ",")
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Quiet Lens",
                                  action: #selector(NSApp.terminate(_:)), keyEquivalent: "q")
        quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        menu.addItem(quitItem)

        // Pop the menu up directly under the status item. Don't assign
        // `statusItem.menu` + `performClick`: that re-enters statusBarClicked
        // while currentEvent is still .rightMouseUp, which calls back into
        // showContextMenu, which calls performClick again — infinite recursion.
        if let btn = statusItem.button {
            let p = NSPoint(x: 0, y: btn.bounds.maxY + 4)
            menu.popUp(positioning: nil, at: p, in: btn)
        }
    }

    @MainActor @objc private func toggleFromMenu() { toggleOverlay() }
    @MainActor @objc private func openSettingsFromMenu() { openSettings() }
    @MainActor func togglePinCurrent() {
        guard let id = windowTracker.currentApp?.bundleIdentifier else { return }
        var list = QuietLensSettings.shared.pinnedBundleIDs
        if let idx = list.firstIndex(of: id) { list.remove(at: idx) } else { list.append(id) }
        QuietLensSettings.shared.pinnedBundleIDs = list
    }

    @MainActor @objc func toggleExcludeCurrent() {
        guard let id = windowTracker.currentApp?.bundleIdentifier else { return }
        var list = QuietLensSettings.shared.excludedBundleIDs
        if let idx = list.firstIndex(of: id) { list.remove(at: idx) } else { list.append(id) }
        QuietLensSettings.shared.excludedBundleIDs = list
        applyCurrentExclusion()
    }

    @MainActor
    private func isCurrentExcluded() -> Bool {
        guard let id = windowTracker.currentApp?.bundleIdentifier else { return false }
        return QuietLensSettings.shared.excludedBundleIDs.contains(id)
    }

    @MainActor
    func toggleOverlay() {
        let willEnable = !overlayManager.isEnabled
        overlayManager.setEnabled(willEnable, animated: true)
        if willEnable {
            // Re-read the frontmost window so the overlay applies to the
            // window the user is looking at right now, not the stale one.
            windowTracker.refresh()
            applyCurrentExclusion()
        }
        applyAutoHide()
        updateStatusIcon()
    }

    @MainActor
    func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView().environmentObject(QuietLensSettings.shared)
            let host = NSHostingController(rootView: view)
            let w = NSWindow(contentViewController: host)
            w.title = "Quiet Lens Settings"
            w.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView, .resizable]
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isMovableByWindowBackground = false
            w.setContentSize(NSSize(width: 920, height: 640))
            // Do NOT override the close button's target/action. The default
            // already routes through the responder chain and closes the
            // window. Setting target = w + action = performClose: causes
            // infinite recursion: performClose simulates a click on the
            // close button, which re-invokes performClose, which simulates
            // another click… stack overflows in __CFStringAppendBytes when
            // AppKit tries to log the runaway.
            w.level = .normal
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            w.delegate = self
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
            w.title = ""
            w.styleMask = [.titled, .closable, .fullSizeContentView]
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isMovableByWindowBackground = false
            w.setContentSize(NSSize(width: 620, height: 760))
            w.center()
            w.isReleasedWhenClosed = false
            w.level = .normal
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            w.delegate = self
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
        let s = QuietLensSettings.shared
        let active = overlayManager.isEnabled && overlayManager.isVisible
        var opts: NSApplication.PresentationOptions = []
        if active && s.autoHideMenuBar { opts.insert(.autoHideMenuBar) }
        NSApp.presentationOptions = opts
    }

    @MainActor
    private enum MenuIconState {
        case off, ambient, deep, excluded
    }

    @MainActor
    private func updateStatusIcon() {
        guard let btn = statusItem?.button else { return }
        let isOn = overlayManager?.isEnabled ?? false
        let excluded = isCurrentExcluded()
        let mode = QuietLensSettings.shared.overlayMode
        let dotEnabled = QuietLensSettings.shared.showIndicatorDot

        let state: MenuIconState
        if excluded { state = .excluded }
        else if isOn && !dotEnabled { state = .off }
        else if isOn && mode == .ambient { state = .ambient }
        else if isOn { state = .deep }
        else { state = .off }

        let image = Self.menuBarImage(state: state)
        btn.image = image
        btn.image?.isTemplate = (state != .ambient)
    }

    private static func menuBarImage(state: MenuIconState) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let img = NSImage(size: size, flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let circleRect = CGRect(x: 1.5, y: 1.5, width: 15, height: 15)
            let center = CGPoint(x: 9, y: 9)
            switch state {
            case .off:
                ctx.setStrokeColor(NSColor.black.cgColor)
                ctx.setLineWidth(1.4)
                ctx.strokeEllipse(in: circleRect)
            case .deep:
                ctx.setFillColor(NSColor.black.cgColor)
                ctx.fillEllipse(in: circleRect)
                ctx.setBlendMode(.destinationOut)
                ctx.setFillColor(NSColor.black.cgColor)
                let innerR: CGFloat = 2.4
                ctx.fillEllipse(in: CGRect(x: center.x - innerR, y: center.y - innerR,
                                           width: innerR*2, height: innerR*2))
            case .ambient:
                let cs = CGColorSpaceCreateDeviceRGB()
                ctx.saveGState()
                ctx.addEllipse(in: circleRect); ctx.clip()
                let grad = CGGradient(colorsSpace: cs, colors: [
                    CGColor(srgbRed: 0.55, green: 0.30, blue: 1.0, alpha: 1),
                    CGColor(srgbRed: 0.10, green: 0.50, blue: 1.0, alpha: 1),
                    CGColor(srgbRed: 0.20, green: 0.85, blue: 1.0, alpha: 1)
                ] as CFArray, locations: [0, 0.5, 1])!
                ctx.drawLinearGradient(grad,
                    start: CGPoint(x: circleRect.minX, y: circleRect.maxY),
                    end: CGPoint(x: circleRect.maxX, y: circleRect.minY),
                    options: [])
                ctx.restoreGState()
            case .excluded:
                ctx.setStrokeColor(NSColor.black.cgColor)
                ctx.setLineWidth(1.4)
                ctx.setLineDash(phase: 0, lengths: [2.2, 1.6])
                ctx.strokeEllipse(in: circleRect)
            }
            return true
        }
        return img
    }
}
