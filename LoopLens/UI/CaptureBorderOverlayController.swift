import AppKit

@MainActor
final class CaptureBorderOverlayController {
    private let panel: NSPanel

    init(region: CaptureRegion, on screen: NSScreen) {
        let localRect = region.appKitRect(displayHeight: screen.frame.height)
        let globalRect = CGRect(
            x: screen.frame.minX + localRect.minX,
            y: screen.frame.minY + localRect.minY,
            width: localRect.width,
            height: localRect.height
        )

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
        panel.contentView = CaptureBorderView(frame: CGRect(origin: .zero, size: globalRect.size))
    }

    func show() {
        panel.orderFrontRegardless()
    }

    func close() {
        panel.orderOut(nil)
    }
}

private final class CaptureBorderView: NSView {
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
    }
}
