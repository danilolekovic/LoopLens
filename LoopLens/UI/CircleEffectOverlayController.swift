import AppKit
import QuartzCore

@MainActor
final class CircleEffectOverlayController {
    private let panel: NSPanel
    private let effectView: CircleEffectView
    private let region: CaptureRegion

    var windowNumber: CGWindowID {
        CGWindowID(panel.windowNumber)
    }

    init(region: CaptureRegion, on screen: NSScreen) {
        self.region = region
        let localRect = region.appKitRect(displayHeight: screen.frame.height)
        let globalRect = CGRect(
            x: screen.frame.minX + localRect.minX,
            y: screen.frame.minY + localRect.minY,
            width: localRect.width,
            height: localRect.height
        )
        effectView = CircleEffectView(frame: CGRect(origin: .zero, size: globalRect.size))
        panel = NSPanel(
            contentRect: globalRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        panel.contentView = effectView
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    }

    func show() {
        panel.orderFrontRegardless()
    }

    func drawCircle(around sourceRect: CGRect) {
        let localRect = CGRect(
            x: sourceRect.minX - region.rect.minX,
            y: region.rect.maxY - sourceRect.maxY,
            width: sourceRect.width,
            height: sourceRect.height
        )
        effectView.drawCircle(in: localRect)
    }

    func close() {
        panel.orderOut(nil)
    }
}

private final class CircleEffectView: NSView {
    private let circleLayer = CAShapeLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        circleLayer.fillColor = NSColor.clear.cgColor
        circleLayer.strokeColor = NSColor.systemYellow.cgColor
        circleLayer.lineWidth = 5
        circleLayer.lineCap = .round
        circleLayer.opacity = 0
        layer?.addSublayer(circleLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func drawCircle(in rect: CGRect) {
        circleLayer.removeAllAnimations()
        circleLayer.path = CGPath(ellipseIn: rect.insetBy(dx: 3, dy: 3), transform: nil)
        circleLayer.opacity = 1

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.beginTime = CACurrentMediaTime() + 0.45
        fade.duration = 0.9
        fade.fillMode = .forwards
        fade.isRemovedOnCompletion = false
        circleLayer.add(fade, forKey: "fade")
    }
}
