import AppKit

@MainActor
final class ShakeDetector {
    var onShake: (() -> Void)?
    var onPeekStart: (() -> Void)?
    var onPeekEnd: (() -> Void)?

    private let settings: QuietLensSettings
    private var timer: Timer?
    private var flagsMonitor: Any?
    private var samples: [(t: TimeInterval, p: CGPoint)] = []
    private var reversals: Int = 0
    private var lastDir: Int = 0
    private var firstReversalTime: TimeInterval = 0
    private var lastTriggerTime: TimeInterval = 0
    private var currentFlags: NSEvent.ModifierFlags = []
    private var peeking: Bool = false
    private var peekResetWork: DispatchWorkItem?

    init(settings: QuietLensSettings) { self.settings = settings }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] ev in
            Task { @MainActor in self?.currentFlags = ev.modifierFlags }
        }
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] ev in
            Task { @MainActor in self?.currentFlags = ev.modifierFlags }
            return ev
        }
    }

    private func tick() {
        guard settings.shakeEnabled else { reset(); return }
        let modifierWanted = settings.shakeModifier.flags
        if !modifierWanted.isEmpty && !currentFlags.contains(modifierWanted) {
            reset()
            return
        }
        let now = Date().timeIntervalSinceReferenceDate
        let loc = NSEvent.mouseLocation
        samples.append((now, loc))
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
        reversals = 0
        lastDir = 0
    }
}
