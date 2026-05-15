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
    private(set) var currentApp: NSRunningApplication?
    private var axObserver: AXObserver?
    private var axApp: AXUIElement?
    private var observedPID: pid_t = 0
    private var pollTimer: Timer?
    private var lastInfo: FocusedWindowInfo?

    func start() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self, selector: #selector(activeAppChanged(_:)),
                       name: NSWorkspace.didActivateApplicationNotification, object: nil)
        nc.addObserver(self, selector: #selector(activeAppChanged(_:)),
                       name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        attachToFrontmost()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
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
        observedPID = pid
        var obs: AXObserver?
        let cb: AXObserverCallback = { _, _, _, refcon in
            guard let refcon else { return }
            let me = Unmanaged<WindowTracker>.fromOpaque(refcon).takeUnretainedValue()
            Task { @MainActor in me.refresh() }
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
        var winRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &winRef) == .success,
              let win = winRef else { return nil }
        let axWin = win as! AXUIElement

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
