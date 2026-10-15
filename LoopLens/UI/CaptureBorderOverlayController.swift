import AppKit

@MainActor
final class CaptureBorderOverlayController {
    private let panel: NSPanel
    private let borderView: CaptureBorderView
    private let region: CaptureRegion

    init(region: CaptureRegion, on screen: NSScreen) {
        self.region = region
        let localRect = region.appKitRect(displayHeight: screen.frame.height)
        let globalRect = CGRect(
            x: screen.frame.minX + localRect.minX,
            y: screen.frame.minY + localRect.minY,
            width: localRect.width,
            height: localRect.height
        )

        borderView = CaptureBorderView(frame: CGRect(origin: .zero, size: globalRect.size))
        panel = NSPanel(
            contentRect: globalRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView = borderView
    }

    func show() {
        panel.orderFrontRegardless()
    }

    func updateZoomRect(_ sourceRect: CGRect, isLocked: Bool) {
        borderView.zoomRect = CGRect(
            x: sourceRect.minX - region.rect.minX,
            y: region.rect.maxY - sourceRect.maxY,
            width: sourceRect.width,
            height: sourceRect.height
        )
        borderView.isZoomLocked = isLocked
        borderView.needsDisplay = true
    }

    func close() {
        panel.orderOut(nil)
    }
}

private final class CaptureBorderView: NSView {
    var zoomRect: CGRect?
    var isZoomLocked = false

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.controlAccentColor.setStroke()
        let border = NSBezierPath(
            roundedRect: bounds.insetBy(dx: 2, dy: 2),
            xRadius: 6,
            yRadius: 6
        )
        border.lineWidth = 4
        border.stroke()

        if let zoomRect {
            let visibleRect = isZoomLocked ? bounds.insetBy(dx: 7, dy: 7) : zoomRect.insetBy(dx: 2, dy: 2)
            NSColor.systemCyan.setStroke()
            let zoomBorder = NSBezierPath(roundedRect: visibleRect, xRadius: 6, yRadius: 6)
            zoomBorder.lineWidth = 3
            zoomBorder.stroke()
        }
    }
}
