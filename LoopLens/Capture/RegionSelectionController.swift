import AppKit

@MainActor
final class RegionSelectionController {
    private var panel: SelectionPanel?
    private var continuation: CheckedContinuation<CGRect?, Never>?

    func selectRegion(on screen: NSScreen) async -> CGRect? {
        await withCheckedContinuation { continuation in
            self.continuation = continuation

            let panel = SelectionPanel(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: screen
            )
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.hasShadow = false

            let selectionView = RegionSelectionView(frame: CGRect(origin: .zero, size: screen.frame.size))
            selectionView.onComplete = { [weak self] rect in
                self?.finish(with: rect)
            }
            panel.contentView = selectionView
            self.panel = panel

            panel.makeKeyAndOrderFront(nil)
            panel.makeFirstResponder(selectionView)
            NSCursor.crosshair.push()
        }
    }

    private func finish(with rect: CGRect?) {
        NSCursor.pop()
        panel?.orderOut(nil)
        panel = nil
        continuation?.resume(returning: rect)
        continuation = nil
    }
}

private final class SelectionPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

private final class RegionSelectionView: NSView {
    var onComplete: ((CGRect?) -> Void)?

    private var startPoint: CGPoint?
    private var selectionRect: CGRect?

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        startPoint = clamped(convert(event.locationInWindow, from: nil))
        selectionRect = nil
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let startPoint else { return }
        let currentPoint = clamped(convert(event.locationInWindow, from: nil))
        selectionRect = CGRect(
            x: min(startPoint.x, currentPoint.x),
            y: min(startPoint.y, currentPoint.y),
            width: abs(currentPoint.x - startPoint.x),
            height: abs(currentPoint.y - startPoint.y)
        )
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let selectionRect, selectionRect.width >= 12, selectionRect.height >= 12 else {
            onComplete?(nil)
            return
        }
        onComplete?(selectionRect.integral)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onComplete?(nil)
        } else {
            super.keyDown(with: event)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.black.withAlphaComponent(0.48).setFill()
        let dimmingPath = NSBezierPath(rect: bounds)
        if let selectionRect {
            dimmingPath.appendRoundedRect(selectionRect, xRadius: 4, yRadius: 4)
            dimmingPath.windingRule = .evenOdd
        }
        dimmingPath.fill()

        if let selectionRect {
            NSColor.controlAccentColor.setStroke()
            let border = NSBezierPath(roundedRect: selectionRect, xRadius: 4, yRadius: 4)
            border.lineWidth = 2
            border.stroke()
            drawSizeLabel(for: selectionRect)
        } else {
            drawInstructions()
        }
    }

    private func drawInstructions() {
        let text = "Drag to select a recording region  •  Escape to cancel"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]
        let size = text.size(withAttributes: attributes)
        text.draw(
            at: CGPoint(x: bounds.midX - size.width / 2, y: bounds.maxY - size.height - 44),
            withAttributes: attributes
        )
    }

    private func drawSizeLabel(for rect: CGRect) {
        let text = "\(Int(rect.width)) × \(Int(rect.height))"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.black.withAlphaComponent(0.72),
        ]
        let size = text.size(withAttributes: attributes)
        let x = min(max(rect.midX - size.width / 2, 8), bounds.maxX - size.width - 8)
        let y = max(rect.minY - size.height - 10, 8)
        text.draw(at: CGPoint(x: x, y: y), withAttributes: attributes)
    }

    private func clamped(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(point.x, bounds.minX), bounds.maxX),
            y: min(max(point.y, bounds.minY), bounds.maxY)
        )
    }
}
