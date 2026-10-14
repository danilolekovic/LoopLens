import AppKit
import Combine
import CoreGraphics
import ScreenCaptureKit

@MainActor
final class ScreenCaptureStore: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case permissionRequired
        case ready
        case capturingPreview
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var displays: [CaptureDisplay] = []
    @Published var selectedDisplayID: CGDirectDisplayID? {
        didSet {
            if selectedDisplayID != oldValue {
                previewImage = nil
            }
        }
    }
    @Published private(set) var previewImage: NSImage?

    private var shareableDisplays: [CGDirectDisplayID: SCDisplay] = [:]

    var selectedDisplay: CaptureDisplay? {
        displays.first { $0.id == selectedDisplayID }
    }

    var isBusy: Bool {
        state == .loading || state == .capturingPreview
    }

    func loadDisplays() async {
        state = .loading

        guard CGPreflightScreenCaptureAccess() else {
            state = .permissionRequired
            return
        }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
            let screensByID: [CGDirectDisplayID: NSScreen] = Dictionary(
                uniqueKeysWithValues: NSScreen.screens.compactMap { screen -> (CGDirectDisplayID, NSScreen)? in
                    guard let number = screen.deviceDescription[.init("NSScreenNumber")] as? NSNumber else {
                        return nil
                    }
                    return (CGDirectDisplayID(number.uint32Value), screen)
                }
            )

            shareableDisplays = Dictionary(
                uniqueKeysWithValues: content.displays.map { ($0.displayID, $0) }
            )
            displays = content.displays
                .map { display in
                    CaptureDisplay(
                        id: display.displayID,
                        name: screensByID[display.displayID]?.localizedName ?? "Display \(display.displayID)",
                        width: display.width,
                        height: display.height,
                        frame: display.frame
                    )
                }
                .sorted { lhs, rhs in
                    if lhs.frame.minX == rhs.frame.minX {
                        return lhs.frame.minY < rhs.frame.minY
                    }
                    return lhs.frame.minX < rhs.frame.minX
                }

            if !displays.contains(where: { $0.id == selectedDisplayID }) {
                selectedDisplayID = displays.first?.id
                previewImage = nil
            }
            state = .ready
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func requestPermission() async {
        guard CGRequestScreenCaptureAccess() else {
            state = .permissionRequired
            return
        }
        await loadDisplays()
    }

    func capturePreview() async {
        guard
            let display = selectedDisplay,
            let shareableDisplay = shareableDisplays[display.id]
        else {
            return
        }

        state = .capturingPreview

        do {
            let filter = SCContentFilter(
                display: shareableDisplay,
                excludingApplications: [],
                exceptingWindows: []
            )
            let configuration = SCStreamConfiguration()
            let previewSize = display.previewSize(maxDimension: 1600)
            configuration.width = max(1, Int(previewSize.width))
            configuration.height = max(1, Int(previewSize.height))
            configuration.showsCursor = true

            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
            previewImage = NSImage(
                cgImage: image,
                size: NSSize(width: image.width, height: image.height)
            )
            state = .ready
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
