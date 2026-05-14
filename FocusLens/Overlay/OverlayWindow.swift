import AppKit
import QuartzCore

final class OverlayWindow: NSWindow {
    private let blurView: BlurOverlayView
    private let cutoutView: CutoutView

    init(screen: NSScreen, frame: NSRect) {
        blurView = BlurOverlayView(frame: NSRect(origin: .zero, size: frame.size))
        cutoutView = CutoutView(frame: NSRect(origin: .zero, size: frame.size))
        super.init(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        setFrame(frame, display: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)) - 1)
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isReleasedWhenClosed = false
        alphaValue = 0

        let root = NSView(frame: NSRect(origin: .zero, size: frame.size))
        root.wantsLayer = true
        root.autoresizingMask = [.width, .height]
        blurView.autoresizingMask = [.width, .height]
        cutoutView.autoresizingMask = [.width, .height]
        root.addSubview(blurView)
        root.addSubview(cutoutView)
        contentView = root
        cutoutView.maskTarget = blurView
        orderFrontRegardless()
    }

    func applyAppearance(settings: FocusLensSettings) {
        blurView.apply(settings: settings)
    }

    func setCutouts(_ rects: [CGRect], duration: TimeInterval) {
        cutoutView.setCutouts(rects, duration: duration)
    }

    func fadeIn(duration: TimeInterval) {
        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = duration
            animator().alphaValue = 1
        }
    }

    func fadeOut(duration: TimeInterval) {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = duration
            animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            if self?.alphaValue ?? 0 < 0.01 { self?.orderOut(nil) }
        })
    }
}
