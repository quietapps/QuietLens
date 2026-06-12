import AppKit

@MainActor
final class ShakeDetector {
    var onShake: (() -> Void)?
    var onPeekStart: (() -> Void)?
    var onPeekEnd: (() -> Void)?

    private let settings: QuietLensSettings
    private var monitors: [Any] = []
    private var started = false
    private var samples: [(t: TimeInterval, p: CGPoint)] = []
    private var lastSampleTime: TimeInterval = 0
    private var lastTriggerTime: TimeInterval = 0
    private var currentFlags: NSEvent.ModifierFlags = []
    private var peeking: Bool = false
    private var peekResetWork: DispatchWorkItem?

    init(settings: QuietLensSettings) { self.settings = settings }

    func start() {
        guard !started else { return }
        started = true
        // Event-driven sampling instead of a 60 Hz polling timer: zero CPU
        // while the pointer is idle. Global monitors cover other apps; local
        // monitors cover our own windows (global monitors skip the active app).
        // Mouse-move global monitors need no extra TCC permission.
        let moveEvents: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        if let m = NSEvent.addGlobalMonitorForEvents(matching: moveEvents, handler: { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }) { monitors.append(m) }
        if let m = NSEvent.addLocalMonitorForEvents(matching: moveEvents, handler: { [weak self] ev in
            Task { @MainActor in self?.sample() }
            return ev
        }) { monitors.append(m) }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] ev in
            let flags = ev.modifierFlags
            Task { @MainActor in self?.currentFlags = flags }
        }) { monitors.append(m) }
        if let m = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] ev in
            let flags = ev.modifierFlags
            Task { @MainActor in self?.currentFlags = flags }
            return ev
        }) { monitors.append(m) }
    }

    private func sample() {
        guard settings.shakeEnabled else {
            if !samples.isEmpty { reset() }
            return
        }
        let modifierWanted = settings.shakeModifier.flags
        if !modifierWanted.isEmpty && !currentFlags.contains(modifierWanted) {
            if !samples.isEmpty { reset() }
            return
        }
        let now = Date().timeIntervalSinceReferenceDate
        // Cap the sampling rate so high-report-rate mice don't burn CPU.
        if now - lastSampleTime < 0.008 { return }
        lastSampleTime = now
        samples.append((now, NSEvent.mouseLocation))
        samples.removeAll { now - $0.t > 0.6 }
        guard samples.count >= 3 else { return }

        var travel: CGFloat = 0
        var reversalCount = 0
        var lastVec = CGVector(dx: 0, dy: 0)
        for i in 1..<samples.count {
            let dx = samples[i].p.x - samples[i - 1].p.x
            let dy = samples[i].p.y - samples[i - 1].p.y
            let mag = sqrt(dx * dx + dy * dy)
            travel += mag
            guard mag > 1 else { continue }
            let nx = dx / mag, ny = dy / mag
            if lastVec.dx != 0 || lastVec.dy != 0 {
                let dot = nx * lastVec.dx + ny * lastVec.dy
                if dot < -0.3 { reversalCount += 1 }
            }
            lastVec = CGVector(dx: nx, dy: ny)
        }

        let sensitivity = settings.shakeSensitivity
        let requiredReversals = max(3, Int(7 - sensitivity * 4))
        let minTravel: CGFloat = CGFloat(500 - sensitivity * 300)

        if reversalCount >= requiredReversals && travel >= minTravel && (now - lastTriggerTime) > 0.6 {
            lastTriggerTime = now
            samples.removeAll()
            if !modifierWanted.isEmpty {
                if !peeking {
                    peeking = true
                    onPeekStart?()
                }
                schedulePeekEnd()
            } else {
                onShake?()
            }
        }
    }

    private func schedulePeekEnd() {
        peekResetWork?.cancel()
        let w = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.peeking = false
                self.onPeekEnd?()
            }
        }
        peekResetWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: w)
    }

    private func reset() {
        samples.removeAll()
    }
}
