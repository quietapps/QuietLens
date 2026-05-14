import AppKit
import QuartzCore

final class CutoutView: NSView {
    weak var maskTarget: NSView?
    private let maskLayer = CAShapeLayer()
    private var currentPath: CGPath?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        maskLayer.fillRule = .evenOdd
        maskLayer.fillColor = NSColor.white.cgColor
    }
    required init?(coder: NSCoder) { fatalError() }

    func setCutouts(_ rects: [CGRect], duration: TimeInterval) {
        let path = CGMutablePath()
        path.addRect(bounds)
        for r in rects {
            let expanded = r.insetBy(dx: -1.5, dy: -1.5)
            let rounded = CGPath(roundedRect: expanded, cornerWidth: 14, cornerHeight: 14, transform: nil)
            path.addPath(rounded)
        }
        guard let target = maskTarget else { return }
        target.wantsLayer = true
        if target.layer?.mask !== maskLayer {
            maskLayer.frame = target.bounds
            target.layer?.mask = maskLayer
        }
        maskLayer.frame = target.bounds
        if duration > 0.01, let old = currentPath {
            let anim = CABasicAnimation(keyPath: "path")
            anim.fromValue = old
            anim.toValue = path
            anim.duration = duration
            anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            maskLayer.add(anim, forKey: "path")
        }
        maskLayer.path = path
        currentPath = path
    }
}
