import AppKit
import ApplicationServices

struct FocusedWindowInfo: Equatable {
    let pid: pid_t
    let bundleID: String?
    let frame: CGRect
    let windowNumber: CGWindowID?
    let allAppFrames: [CGRect]
}

@MainActor
final class WindowTracker {
    var onFocusedWindowChanged: ((FocusedWindowInfo?) -> Void)?
    /// Fires when the focused window is being moved or resized (AX
    /// kAXWindowMoved / kAXWindowResized). Used to hide the overlay only
    /// during real window drags instead of on every mouse drag.
    var onWindowGeometryChanged: (() -> Void)?
    private(set) var currentApp: NSRunningApplication?
    private var axObserver: AXObserver?
    private var axApp: AXUIElement?
    private var observedPID: pid_t = 0
    private var pollTimer: Timer?
    private var lastInfo: FocusedWindowInfo?
    private var startedTracking = false
    private var pollingDesired = false

    func start() {
        guard !startedTracking else { return }
        startedTracking = true
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self, selector: #selector(activeAppChanged(_:)),
                       name: NSWorkspace.didActivateApplicationNotification, object: nil)
        nc.addObserver(self, selector: #selector(activeAppChanged(_:)),
                       name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        attachToFrontmost()
        if pollingDesired { startPollTimer() }
    }

    /// The 0.5s poll is only a fallback for AX events the observer misses.
    /// It costs an AX round-trip + CGWindowList scan per tick, so it runs
    /// only while the overlay is enabled.
    func setPollingEnabled(_ on: Bool) {
        pollingDesired = on
        guard startedTracking else { return }
        if on {
            startPollTimer()
        } else {
            pollTimer?.invalidate()
            pollTimer = nil
        }
    }

    private func startPollTimer() {
        guard pollTimer == nil else { return }
        let t = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        t.tolerance = 0.1
        pollTimer = t
    }

    @objc private func activeAppChanged(_ note: Notification) {
        Task { @MainActor in self.attachToFrontmost() }
    }

    private func attachToFrontmost() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        currentApp = app
        attachAXObserver(pid: app.processIdentifier)
        refresh()
    }

    private func attachAXObserver(pid: pid_t) {
        if let obs = axObserver {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .defaultMode)
        }
        axObserver = nil
        axApp = AXUIElementCreateApplication(pid)
        if let app = axApp { AXUIElementSetMessagingTimeout(app, 0.4) }
        observedPID = pid
        var obs: AXObserver?
        let cb: AXObserverCallback = { _, _, notification, refcon in
            guard let refcon else { return }
            let me = Unmanaged<WindowTracker>.fromOpaque(refcon).takeUnretainedValue()
            let name = notification as String
            let isGeometry = name == kAXWindowMovedNotification || name == kAXWindowResizedNotification
            Task { @MainActor in
                if isGeometry { me.onWindowGeometryChanged?() }
                me.refresh()
            }
        }
        if AXObserverCreate(pid, cb, &obs) == .success, let obs {
            let refcon = Unmanaged.passUnretained(self).toOpaque()
            AXObserverAddNotification(obs, axApp!, kAXFocusedWindowChangedNotification as CFString, refcon)
            AXObserverAddNotification(obs, axApp!, kAXMainWindowChangedNotification as CFString, refcon)
            AXObserverAddNotification(obs, axApp!, kAXWindowMovedNotification as CFString, refcon)
            AXObserverAddNotification(obs, axApp!, kAXWindowResizedNotification as CFString, refcon)
            CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .defaultMode)
            axObserver = obs
        }
    }

    func refresh() {
        let info = readFocusedWindow()
        if info != lastInfo {
            lastInfo = info
            onFocusedWindowChanged?(info)
        }
    }

    private func readFocusedWindow() -> FocusedWindowInfo? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        currentApp = app
        let pid = app.processIdentifier
        let axApp = AXUIElementCreateApplication(pid)
        // Prevent main-thread hangs if the target app's AX server is unresponsive.
        AXUIElementSetMessagingTimeout(axApp, 0.4)
        var winRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &winRef) == .success,
              let win = winRef else { return nil }
        let axWin = win as! AXUIElement
        AXUIElementSetMessagingTimeout(axWin, 0.4)

        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        AXUIElementCopyAttributeValue(axWin, kAXPositionAttribute as CFString, &posRef)
        AXUIElementCopyAttributeValue(axWin, kAXSizeAttribute as CFString, &sizeRef)
        var pos = CGPoint.zero
        var size = CGSize.zero
        if let p = posRef { AXValueGetValue(p as! AXValue, .cgPoint, &pos) }
        if let s = sizeRef { AXValueGetValue(s as! AXValue, .cgSize, &size) }
        let frame = CGRect(origin: pos, size: size)

        var winNum: CGWindowID?
        var idRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(axWin, "_AXWindowID" as CFString, &idRef) == .success,
           let n = idRef as? NSNumber {
            winNum = CGWindowID(n.uint32Value)
        }

        let allFrames = listAllWindowFrames(pid: pid)
        return FocusedWindowInfo(pid: pid, bundleID: app.bundleIdentifier,
                                 frame: frame, windowNumber: winNum, allAppFrames: allFrames)
    }

    private func listAllWindowFrames(pid: pid_t) -> [CGRect] {
        let opts: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let arr = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] else { return [] }
        var out: [CGRect] = []
        for d in arr {
            guard let p = d[kCGWindowOwnerPID as String] as? pid_t, p == pid else { continue }
            guard let b = d[kCGWindowBounds as String] as? [String: Any],
                  let r = CGRect(dictionaryRepresentation: b as CFDictionary) else { continue }
            if r.width < 40 || r.height < 40 { continue }
            out.append(r)
        }
        return out
    }
}
