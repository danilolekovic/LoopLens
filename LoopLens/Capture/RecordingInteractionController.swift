import AppKit

@MainActor
final class RecordingInteractionController {
    private let region: CaptureRegion
    private let screen: NSScreen
    private let borderOverlay: CaptureBorderOverlayController
    private let zoomAction: @MainActor (CGRect) -> Void
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var zoomScale: CGFloat = 1

    init(
        region: CaptureRegion,
        screen: NSScreen,
        borderOverlay: CaptureBorderOverlayController,
        zoomAction: @escaping @MainActor (CGRect) -> Void
    ) {
        self.region = region
        self.screen = screen
        self.borderOverlay = borderOverlay
        self.zoomAction = zoomAction
    }

    func start() {
        let mask: NSEvent.EventTypeMask = [.magnify]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            Task { @MainActor in self?.handle(event) }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
    }

    private func handle(_ event: NSEvent) {
        if event.type == .magnify {
            handleMagnification(event.magnification, around: NSEvent.mouseLocation)
        }
    }

    private func handleMagnification(_ magnification: CGFloat, around globalPoint: CGPoint) {
        guard let sourcePoint = sourcePoint(from: globalPoint), region.rect.contains(sourcePoint) else {
            return
        }

        zoomScale = min(4, max(1, zoomScale * (1 + magnification)))
        if zoomScale < 1.12 {
            zoomScale = 1
        }

        let width = region.rect.width / zoomScale
        let height = region.rect.height / zoomScale
        let x = min(max(sourcePoint.x - width / 2, region.rect.minX), region.rect.maxX - width)
        let y = min(max(sourcePoint.y - height / 2, region.rect.minY), region.rect.maxY - height)
        let zoomRect = CGRect(x: x, y: y, width: width, height: height).integral

        borderOverlay.updateZoomRect(zoomRect, isLocked: zoomScale == 1)
        zoomAction(zoomRect)
    }

    private func sourcePoint(from globalPoint: CGPoint) -> CGPoint? {
        guard screen.frame.contains(globalPoint) else { return nil }
        let localPoint = CGPoint(
            x: globalPoint.x - screen.frame.minX,
            y: globalPoint.y - screen.frame.minY
        )
        return CGPoint(x: localPoint.x, y: screen.frame.height - localPoint.y)
    }
}
