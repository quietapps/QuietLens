import AppKit
import CoreImage
import QuartzCore

final class BlurOverlayView: NSView {
    private let effect: NSVisualEffectView
    private let tintLayer = CALayer()
    private let gradientLayer = CAGradientLayer()
    private let grainLayer = CALayer()
    private let backdropLayer = CALayer()
    private var lastBackdropKey: String = ""

    override init(frame frameRect: NSRect) {
        effect = NSVisualEffectView(frame: frameRect)
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
        effect.autoresizingMask = [.width, .height]
        effect.blendingMode = .behindWindow
        effect.material = .windowBackground
        effect.state = .active
        effect.appearance = NSAppearance(named: .darkAqua)
        addSubview(effect)
        backdropLayer.frame = bounds
        backdropLayer.contentsGravity = .resizeAspectFill
        backdropLayer.isHidden = true
        tintLayer.frame = bounds
        gradientLayer.frame = bounds
        grainLayer.frame = bounds
        grainLayer.contentsGravity = .resizeAspectFill
        layer?.addSublayer(backdropLayer)
        layer?.addSublayer(tintLayer)
        layer?.addSublayer(gradientLayer)
        layer?.addSublayer(grainLayer)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        effect.frame = bounds
        backdropLayer.frame = bounds
        tintLayer.frame = bounds
        gradientLayer.frame = bounds
        grainLayer.frame = bounds
        CATransaction.commit()
    }

    func apply(settings: FocusLensSettings) {
        let radius = max(0, min(50, settings.blurRadius))
        let isAmbient = settings.overlayMode == .ambient
        let isTinted = settings.overlayMode == .tinted

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let useBackdropImage = settings.backdropMode != .blur
        if useBackdropImage {
            applyBackdropImage(settings: settings)
            backdropLayer.isHidden = false
            effect.isHidden = true
        } else if radius < 0.5 {
            backdropLayer.isHidden = true
            effect.isHidden = true
        } else {
            backdropLayer.isHidden = true
            effect.isHidden = false
            // Material picks blur strength. Stronger materials = heavier blur.
            // .hudWindow ~20px, .underWindowBackground ~30px, .fullScreenUI ~50px,
            // .menu ~60px (heaviest standard material).
            switch radius {
            case ..<10: effect.material = .hudWindow
            case ..<25: effect.material = .underWindowBackground
            case ..<40: effect.material = .fullScreenUI
            default: effect.material = .menu
            }
            // Keep effect at full alpha so blur is always strong.
            // Mode dims blur slightly so Ambient feels lighter.
            let modeMul: CGFloat = isAmbient ? 0.65 : 1.0
            effect.alphaValue = CGFloat(modeMul)
        }

        let opacity = max(0.1, min(1.0, settings.overlayOpacity)) * (isTinted ? 1.2 : 1.0)

        let useGradient = settings.gradientEnabled || isAmbient
        if useGradient {
            tintLayer.isHidden = true
            gradientLayer.isHidden = false
            if isAmbient && !settings.gradientEnabled {
                let tint = settings.effectiveTintColor
                let topAlpha: CGFloat = 0.0
                let bottomAlpha: CGFloat = opacity * 0.55
                gradientLayer.colors = [
                    tint.withAlphaComponent(topAlpha).cgColor,
                    tint.withAlphaComponent(bottomAlpha).cgColor
                ]
                gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
                gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
            } else {
                let scale: CGFloat = isAmbient ? 0.55 : 1.0
                let c1 = settings.effectiveTintColor.withAlphaComponent(opacity * scale).cgColor
                let c2 = settings.effectiveTintColor2.withAlphaComponent(opacity * scale).cgColor
                gradientLayer.colors = [c1, c2]
                let rad = settings.gradientAngle * .pi / 180.0
                let dx = 0.5 * cos(rad), dy = 0.5 * sin(rad)
                gradientLayer.startPoint = CGPoint(x: 0.5 - dx, y: 0.5 - dy)
                gradientLayer.endPoint = CGPoint(x: 0.5 + dx, y: 0.5 + dy)
            }
        } else {
            gradientLayer.isHidden = true
            tintLayer.isHidden = false
            tintLayer.backgroundColor = settings.effectiveTintColor.withAlphaComponent(opacity).cgColor
        }

        if settings.grainIntensity > 0.01 {
            if grainLayer.contents == nil { grainLayer.contents = Self.grainImage() }
            grainLayer.contentsGravity = .resize
            grainLayer.magnificationFilter = .nearest
            grainLayer.minificationFilter = .nearest
            grainLayer.compositingFilter = "softLightBlendMode"
            grainLayer.opacity = Float(0.05 + 0.35 * settings.grainIntensity)
            grainLayer.isHidden = false
        } else {
            grainLayer.isHidden = true
        }

        if settings.grayscale {
            let f = CIFilter(name: "CIColorControls")!
            f.setValue(0, forKey: kCIInputSaturationKey)
            layer?.filters = [f]
        } else {
            layer?.filters = nil
        }

        CATransaction.commit()

        applyShader(mode: settings.shaderMode, speed: settings.animationSpeed)
    }

    private func applyShader(mode: ShaderMode, speed: Double) {
        layer?.removeAnimation(forKey: "shader")
        layer?.opacity = 1
        layer?.transform = CATransform3DIdentity
        let s = max(0.1, speed)
        switch mode {
        case .staticMode:
            return
        case .breathing:
            let a = CABasicAnimation(keyPath: "opacity")
            a.fromValue = 0.75
            a.toValue = 1.0
            a.duration = 3.0 / s
            a.autoreverses = true
            a.repeatCount = .infinity
            a.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            layer?.add(a, forKey: "shader")
        case .pulse:
            let a = CABasicAnimation(keyPath: "transform.scale")
            a.fromValue = 1.0
            a.toValue = 1.015
            a.duration = 1.4 / s
            a.autoreverses = true
            a.repeatCount = .infinity
            a.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            layer?.add(a, forKey: "shader")
        case .drift:
            let g = CAAnimationGroup()
            let tx = CAKeyframeAnimation(keyPath: "transform.translation.x")
            tx.values = [0, 8, 0, -8, 0]
            let ty = CAKeyframeAnimation(keyPath: "transform.translation.y")
            ty.values = [0, -6, 0, 6, 0]
            g.animations = [tx, ty]
            g.duration = 7.0 / s
            g.repeatCount = .infinity
            layer?.add(g, forKey: "shader")
        }
    }

    private func applyBackdropImage(settings: FocusLensSettings) {
        let key: String
        let imageURL: URL?
        switch settings.backdropMode {
        case .blur:
            imageURL = nil
            key = ""
        case .image:
            if let p = settings.backdropImagePath, !p.isEmpty {
                imageURL = URL(fileURLWithPath: p)
                key = "image:\(p)"
            } else {
                imageURL = nil
                key = "image:nil"
            }
        case .wallpaper:
            if let screen = window?.screen ?? NSScreen.main {
                imageURL = NSWorkspace.shared.desktopImageURL(for: screen)
                key = "wallpaper:\(imageURL?.path ?? "nil")"
            } else {
                imageURL = nil
                key = "wallpaper:nil"
            }
        }
        guard key != lastBackdropKey else { return }
        lastBackdropKey = key
        if let url = imageURL, let image = NSImage(contentsOf: url) {
            var rect = NSRect(origin: .zero, size: image.size)
            backdropLayer.contents = image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        } else {
            backdropLayer.contents = nil
        }
    }

    private static var cachedGrain: CGImage?
    static func grainImage() -> CGImage? {
        if let g = cachedGrain { return g }
        let w = 2048, h = 2048
        let cs = CGColorSpaceCreateDeviceRGB()
        let bpr = w * 4
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: bpr, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let buf = ctx.data!.assumingMemoryBound(to: UInt8.self)
        for i in 0..<(w * h) {
            let a = Int(UInt8.random(in: 0...255))
            let b = Int(UInt8.random(in: 0...255))
            let c = Int(UInt8.random(in: 0...255))
            let d = Int(UInt8.random(in: 0...255))
            let avg = (a + b + c + d) / 4
            let v = UInt8(96 + (avg - 128) * 80 / 128 + 64)
            buf[i * 4 + 0] = v
            buf[i * 4 + 1] = v
            buf[i * 4 + 2] = v
            buf[i * 4 + 3] = 255
        }
        cachedGrain = ctx.makeImage()
        return cachedGrain
    }
}
