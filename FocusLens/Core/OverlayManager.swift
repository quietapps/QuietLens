import AppKit
import Combine

@MainActor
final class OverlayManager {
    private(set) var isEnabled: Bool = false
    private(set) var isVisible: Bool = false
    private var isExcluded: Bool = false
    private var isPeeking: Bool = false
    private var isDragging: Bool = false

    private var windows: [CGDirectDisplayID: OverlayWindow] = [:]
    private let settings: FocusLensSettings
    private var focused: FocusedWindowInfo?

    init(settings: FocusLensSettings) {
        self.settings = settings
        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        observeDrag()
    }

    func setEnabled(_ on: Bool, animated: Bool) {
        isEnabled = on
        updateVisibility(animated: animated)
    }

    func setExcluded(_ ex: Bool, animated: Bool) {
        isExcluded = ex
        updateVisibility(animated: animated)
    }

    func peek(_ on: Bool) {
        isPeeking = on
        updateVisibility(animated: true)
    }

    func updateFocus(_ info: FocusedWindowInfo?, animated: Bool) {
        focused = info
        refreshCutouts(animated: animated)
    }

    func refreshAppearance() {
        for (_, w) in windows { w.applyAppearance(settings: settings) }
    }

    func refreshGeometry() {
        for (id, w) in windows {
            guard let screen = NSScreen.screens.first(where: { screenID($0) == id }) else { continue }
            w.setFrame(overlayFrame(for: screen), display: true)
        }
        refreshCutouts(animated: false)
    }

    @objc private func screensChanged() {
        rebuildWindows()
        refreshCutouts(animated: false)
    }

    private func observeDrag() {
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] _ in
            Task { @MainActor in self?.setDragging(true) }
        }
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
            Task { @MainActor in self?.setDragging(false) }
        }
    }

    private func setDragging(_ d: Bool) {
        guard isDragging != d else { return }
        isDragging = d
        updateVisibility(animated: true)
    }

    private func shouldBeVisible() -> Bool {
        guard isEnabled else { return false }
        if isExcluded { return false }
        if isPeeking { return false }
        if isDragging { return false }
        return true
    }

    private func updateVisibility(animated: Bool) {
        let visible = shouldBeVisible()
        isVisible = visible
        if visible {
            ensureWindows()
            for (_, w) in windows {
                w.fadeIn(duration: animated ? settings.fadeDuration : 0)
            }
            refreshCutouts(animated: animated)
        } else {
            for (_, w) in windows {
                w.fadeOut(duration: animated ? settings.fadeDuration : 0)
            }
            WindowRaiser.shared.clearAll()
        }
    }

    private func ensureWindows() {
        if windows.isEmpty { rebuildWindows() }
    }

    private func rebuildWindows() {
        for (_, w) in windows { w.orderOut(nil) }
        windows.removeAll()
        for screen in NSScreen.screens {
            let frame = overlayFrame(for: screen)
            let w = OverlayWindow(screen: screen, frame: frame)
            w.applyAppearance(settings: settings)
            windows[screenID(screen)] = w
        }
    }

    private func screenID(_ s: NSScreen) -> CGDirectDisplayID {
        (s.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }

    private func overlayFrame(for screen: NSScreen) -> NSRect {
        let full = screen.frame
        let vis = screen.visibleFrame
        var rect = full
        if !settings.autoHideMenuBar {
            let menuBarHeight = full.maxY - vis.maxY
            if menuBarHeight > 0 {
                rect.size.height -= menuBarHeight
            }
        }
        if !settings.autoHideDock {
            let dockBottom = vis.minY - full.minY
            let dockLeft = vis.minX - full.minX
            let dockRight = full.maxX - vis.maxX
            if dockBottom > 0 {
                rect.origin.y += dockBottom
                rect.size.height -= dockBottom
            }
            if dockLeft > 0 {
                rect.origin.x += dockLeft
                rect.size.width -= dockLeft
            }
            if dockRight > 0 {
                rect.size.width -= dockRight
            }
        }
        return rect
    }

    private func refreshCutouts(animated: Bool) {
        guard isVisible else {
            WindowRaiser.shared.clearAll()
            return
        }
        let perScreen = computePerScreenWindows()
        var allIDs = Set<CGWindowID>()
        for (id, w) in windows {
            guard NSScreen.screens.first(where: { screenID($0) == id }) != nil else { continue }
            let overlayRect = w.frame
            let entries = perScreen[id] ?? []
            let cutouts = entries.compactMap { entry -> CGRect? in
                let inter = entry.rect.intersection(overlayRect)
                if inter.isNull || inter.isEmpty { return nil }
                return CGRect(x: inter.minX - overlayRect.minX,
                              y: inter.minY - overlayRect.minY,
                              width: inter.width, height: inter.height)
            }
            for e in entries where e.windowID != 0 { allIDs.insert(e.windowID) }
            w.setCutouts(cutouts, duration: animated ? settings.fadeDuration : 0)
        }
        let raiseLevel = Int32(CGWindowLevelForKey(.screenSaverWindow))
        WindowRaiser.shared.setRaised(allIDs, level: raiseLevel)
    }

    struct WindowEntry {
        let windowID: CGWindowID
        let rect: CGRect
    }

    private func computePerScreenWindows() -> [CGDirectDisplayID: [WindowEntry]] {
        let opts: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let arr = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] else { return [:] }

        struct CGEntry {
            let windowID: CGWindowID
            let pid: pid_t
            let rect: CGRect
        }
        var entries: [CGEntry] = []
        for d in arr {
            let layer = (d[kCGWindowLayer as String] as? Int) ?? 0
            if layer > 0 { continue }
            let onScreen = (d[kCGWindowIsOnscreen as String] as? Bool) ?? true
            if !onScreen { continue }
            guard let pid = d[kCGWindowOwnerPID as String] as? pid_t else { continue }
            guard let b = d[kCGWindowBounds as String] as? [String: Any],
                  let r = CGRect(dictionaryRepresentation: b as CFDictionary) else { continue }
            let alpha = (d[kCGWindowAlpha as String] as? Double) ?? 1.0
            if alpha < 0.05 { continue }
            if r.width < 40 || r.height < 30 { continue }
            let wid = (d[kCGWindowNumber as String] as? CGWindowID) ?? 0
            entries.append(CGEntry(windowID: wid, pid: pid, rect: cgToCocoa(r)))
        }

        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1
        let pinnedIDs = Set(settings.pinnedBundleIDs)
        let pinnedPIDs: Set<pid_t> = {
            guard !pinnedIDs.isEmpty else { return [] }
            return Set(NSWorkspace.shared.runningApplications.compactMap { app in
                guard let bid = app.bundleIdentifier, pinnedIDs.contains(bid) else { return nil }
                return app.processIdentifier
            })
        }()
        var out: [CGDirectDisplayID: [WindowEntry]] = [:]

        for screen in NSScreen.screens {
            let id = screenID(screen)
            let sf = screen.frame
            var picked: [WindowEntry] = []

            for e in entries where pinnedPIDs.contains(e.pid) && e.rect.intersects(sf) {
                picked.append(WindowEntry(windowID: e.windowID, rect: e.rect))
            }

            if settings.highlightSameAppWindows {
                for e in entries where e.pid == frontPID {
                    if e.rect.intersects(sf) && !picked.contains(where: { rectsApproxEqual($0.rect, e.rect) }) {
                        picked.append(WindowEntry(windowID: e.windowID, rect: e.rect))
                    }
                }
                if let ax = focused?.frame, focused?.pid == frontPID {
                    let cocoa = axToCocoa(ax)
                    if cocoa.intersects(sf) && !picked.contains(where: { rectsApproxEqual($0.rect, cocoa) }) {
                        let wid = focused?.windowNumber ?? 0
                        picked.append(WindowEntry(windowID: wid, rect: cocoa))
                    }
                }
                if picked.isEmpty, let top = entries.first(where: { $0.rect.intersects(sf) }) {
                    picked.append(WindowEntry(windowID: top.windowID, rect: top.rect))
                }
            } else {
                if let ax = focused?.frame, focused?.pid == frontPID {
                    let cocoa = axToCocoa(ax)
                    if cocoa.intersects(sf) {
                        let wid = focused?.windowNumber ?? entries.first(where: { $0.pid == frontPID && rectsApproxEqual($0.rect, cocoa) })?.windowID ?? 0
                        picked.append(WindowEntry(windowID: wid, rect: cocoa))
                    }
                }
                if picked.isEmpty,
                   let top = entries.first(where: { $0.pid == frontPID && $0.rect.intersects(sf) }) {
                    picked.append(WindowEntry(windowID: top.windowID, rect: top.rect))
                }
                if picked.isEmpty,
                   let any = entries.first(where: { $0.rect.intersects(sf) }) {
                    picked.append(WindowEntry(windowID: any.windowID, rect: any.rect))
                }
            }
            out[id] = picked
        }
        return out
    }

    private func axToCocoa(_ r: CGRect) -> CGRect {
        guard let primary = NSScreen.screens.first else { return r }
        let topY = primary.frame.maxY
        return CGRect(x: r.origin.x, y: topY - r.origin.y - r.size.height, width: r.size.width, height: r.size.height)
    }

    private func rectsApproxEqual(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) < 4 && abs(a.minY - b.minY) < 4 &&
        abs(a.width - b.width) < 4 && abs(a.height - b.height) < 4
    }

    private func cgToCocoa(_ r: CGRect) -> CGRect {
        guard let primary = NSScreen.screens.first else { return r }
        let topY = primary.frame.maxY
        return CGRect(x: r.origin.x, y: topY - r.origin.y - r.size.height, width: r.size.width, height: r.size.height)
    }
}
