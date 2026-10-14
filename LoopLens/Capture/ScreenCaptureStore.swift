import AppKit
import Combine
import CoreGraphics
import CoreMedia
import ScreenCaptureKit

@MainActor
final class ScreenCaptureStore: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case permissionRequired
        case restartRequired
        case ready
        case selectingRegion
        case capturingPreview
        case recording
        case finishingRecording
        case exportingGIF(Double)
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var displays: [CaptureDisplay] = []
    @Published var selectedDisplayID: CGDirectDisplayID? {
        didSet {
            if selectedDisplayID != oldValue {
                previewImage = nil
                captureRegion = nil
            }
        }
    }
    @Published private(set) var previewImage: NSImage?
    @Published private(set) var lastRecordingURL: URL?
    @Published private(set) var lastGIFURL: URL?
    @Published private(set) var outputFolderURL: URL
    @Published private(set) var captureRegion: CaptureRegion?
    @Published var recordingName = "LoopLens Recording"
    @Published var gifFramesPerSecond = 15
    @Published var gifMaxDimension = 960
    @Published var usesRecordingFloaty: Bool {
        didSet { defaults.set(usesRecordingFloaty, forKey: PreferenceKey.usesRecordingFloaty) }
    }
    @Published var excludesLoopLensFromCapture: Bool {
        didSet { defaults.set(excludesLoopLensFromCapture, forKey: PreferenceKey.excludesLoopLensFromCapture) }
    }

    private var shareableDisplays: [CGDirectDisplayID: SCDisplay] = [:]
    private var screens: [CGDirectDisplayID: NSScreen] = [:]
    private var applications: [SCRunningApplication] = []
    private var recordingSession: ScreenRecordingSession?
    private var regionSelectionController: RegionSelectionController?
    private var recordingFloatyController: RecordingFloatyController?
    private var hiddenWindows: [NSWindow] = []
    private let gifEncoder = GIFEncoder()
    private let defaults: UserDefaults
    private let outputFolderManager: OutputFolderManager

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let outputFolderManager = OutputFolderManager(defaults: defaults)
        self.outputFolderManager = outputFolderManager
        outputFolderURL = outputFolderManager.savedURL() ?? outputFolderManager.defaultURL
        usesRecordingFloaty = defaults.object(forKey: PreferenceKey.usesRecordingFloaty) as? Bool ?? true
        excludesLoopLensFromCapture = defaults.object(
            forKey: PreferenceKey.excludesLoopLensFromCapture
        ) as? Bool ?? true
    }

    var selectedDisplay: CaptureDisplay? {
        displays.first { $0.id == selectedDisplayID }
    }

    var isBusy: Bool {
        switch state {
        case .loading, .selectingRegion, .capturingPreview, .finishingRecording, .exportingGIF:
            true
        default:
            false
        }
    }

    var isRecording: Bool {
        state == .recording || state == .finishingRecording
    }

    var safeRecordingName: String {
        let trimmed = recordingName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = trimmed.isEmpty ? "LoopLens Recording" : trimmed
        let invalidCharacters = CharacterSet(charactersIn: "/:")
        return fallback.components(separatedBy: invalidCharacters).joined(separator: "-")
    }

    var usesDefaultOutputFolder: Bool {
        outputFolderURL.standardizedFileURL == outputFolderManager.defaultURL.standardizedFileURL
    }

    func loadDisplays() async {
        state = .loading

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
            screens = screensByID

            shareableDisplays = Dictionary(
                uniqueKeysWithValues: content.displays.map { ($0.displayID, $0) }
            )
            applications = content.applications
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
            state = permissionState(for: error)
        }
    }

    func requestPermission() async {
        if CGRequestScreenCaptureAccess() {
            state = .restartRequired
        } else {
            openScreenRecordingSettings()
            state = .permissionRequired
        }
    }

    func quitApplication() {
        NSApplication.shared.terminate(nil)
    }

    func selectRegion() async {
        guard
            state == .ready,
            let display = selectedDisplay,
            let screen = screens[display.id]
        else {
            return
        }

        state = .selectingRegion
        let appWindows = NSApplication.shared.windows.filter { $0.isVisible }
        appWindows.forEach { $0.orderOut(nil) }

        let controller = RegionSelectionController()
        regionSelectionController = controller
        let appKitRect = await controller.selectRegion(on: screen)
        regionSelectionController = nil

        appWindows.forEach { $0.makeKeyAndOrderFront(nil) }
        NSApplication.shared.activate(ignoringOtherApps: true)

        if let appKitRect {
            captureRegion = CaptureRegion(
                appKitRect: appKitRect,
                displayHeight: screen.frame.height
            )
            previewImage = nil
        }
        state = .ready
    }

    func clearRegion() {
        captureRegion = nil
        previewImage = nil
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
            let filter = contentFilter(for: shareableDisplay)
            let configuration = SCStreamConfiguration()
            let previewSize = outputSize(for: display, maxDimension: 1600)
            configuration.width = max(1, Int(previewSize.width))
            configuration.height = max(1, Int(previewSize.height))
            configuration.showsCursor = true
            if let captureRegion {
                configuration.sourceRect = captureRegion.rect
            }

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

    func startRecording() async {
        guard
            state == .ready,
            let display = selectedDisplay,
            let shareableDisplay = shareableDisplays[display.id]
        else {
            return
        }

        removeTemporaryRecording()
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("LoopLens-\(UUID().uuidString)")
            .appendingPathExtension("mov")
        let session = ScreenRecordingSession(outputURL: outputURL)

        do {
            let size = outputSize(for: display, maxDimension: 1920)
            let configuration = SCStreamConfiguration()
            configuration.width = max(1, Int(size.width))
            configuration.height = max(1, Int(size.height))
            configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
            configuration.queueDepth = 5
            configuration.pixelFormat = kCVPixelFormatType_32BGRA
            configuration.showsCursor = true
            if let captureRegion {
                configuration.sourceRect = captureRegion.rect
            }

            try await session.start(
                filter: contentFilter(for: shareableDisplay),
                configuration: configuration
            )
            recordingSession = session
            lastGIFURL = nil
            state = .recording
            enterRecordingPresentation(on: screens[display.id])
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            state = .failed(error.localizedDescription)
        }
    }

    func stopRecording() async {
        guard let recordingSession else { return }
        state = .finishingRecording

        do {
            lastRecordingURL = try await recordingSession.stop()
            self.recordingSession = nil
            state = .ready
            leaveRecordingPresentation()
            await Task.yield()
            await saveGIFAutomatically()
        } catch {
            self.recordingSession = nil
            leaveRecordingPresentation()
            state = .failed(error.localizedDescription)
        }
    }

    func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = outputFolderURL
        panel.prompt = "Choose"
        panel.message = "Choose where LoopLens saves finished GIFs."

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try outputFolderManager.save(url)
            outputFolderURL = url
        } catch {
            state = .failed("Could not remember the output folder: \(error.localizedDescription)")
        }
    }

    func restoreDefaultOutputFolder() {
        outputFolderManager.reset()
        outputFolderURL = outputFolderManager.defaultURL
    }

    private func saveGIFAutomatically() async {
        guard let lastRecordingURL else { return }

        let folderURL = outputFolderURL
        let isSecurityScoped = folderURL.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }

        let destinationURL = outputFolderManager.availableURL(
            for: safeRecordingName,
            in: folderURL
        )

        do {
            try FileManager.default.createDirectory(
                at: folderURL,
                withIntermediateDirectories: true
            )

            state = .exportingGIF(0)
            let settings = GIFExportSettings(
                framesPerSecond: gifFramesPerSecond,
                maxDimension: gifMaxDimension
            )
            try await gifEncoder.encode(
                sourceURL: lastRecordingURL,
                destinationURL: destinationURL,
                settings: settings
            ) { [weak self] progress in
                self?.state = .exportingGIF(progress)
            }
            lastGIFURL = destinationURL
            state = .ready
        } catch {
            try? FileManager.default.removeItem(at: destinationURL)
            state = .failed(error.localizedDescription)
        }
    }

    private func contentFilter(for display: SCDisplay) -> SCContentFilter {
        let ownApplications = excludesLoopLensFromCapture
            ? applications.filter { $0.bundleIdentifier == Bundle.main.bundleIdentifier }
            : []
        return SCContentFilter(
            display: display,
            excludingApplications: ownApplications,
            exceptingWindows: []
        )
    }

    private func outputSize(for display: CaptureDisplay, maxDimension: Int) -> CGSize {
        guard
            let captureRegion,
            let screen = screens[display.id]
        else {
            return display.previewSize(maxDimension: maxDimension)
        }

        return captureRegion.outputSize(
            backingScaleFactor: screen.backingScaleFactor,
            maxDimension: maxDimension
        )
    }

    private func enterRecordingPresentation(on screen: NSScreen?) {
        guard usesRecordingFloaty else { return }

        hiddenWindows = NSApplication.shared.windows.filter { $0.isVisible }
        hiddenWindows.forEach { $0.orderOut(nil) }

        let controller = RecordingFloatyController { [weak self] in
            Task { await self?.stopRecording() }
        }
        recordingFloatyController = controller
        controller.show(on: screen)
    }

    private func leaveRecordingPresentation() {
        recordingFloatyController?.close()
        recordingFloatyController = nil

        hiddenWindows.forEach { $0.makeKeyAndOrderFront(nil) }
        hiddenWindows.removeAll()
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func removeTemporaryRecording() {
        guard let lastRecordingURL else { return }
        try? FileManager.default.removeItem(at: lastRecordingURL)
        self.lastRecordingURL = nil
    }

    private func permissionState(for error: Error) -> State {
        let error = error as NSError
        guard
            error.domain == SCStreamError.errorDomain,
            error.code == SCStreamError.Code.userDeclined.rawValue
        else {
            return .failed(error.localizedDescription)
        }

        return CGPreflightScreenCaptureAccess() ? .restartRequired : .permissionRequired
    }

    private func openScreenRecordingSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private enum PreferenceKey {
        static let usesRecordingFloaty = "usesRecordingFloaty"
        static let excludesLoopLensFromCapture = "excludesLoopLensFromCapture"
    }
}
