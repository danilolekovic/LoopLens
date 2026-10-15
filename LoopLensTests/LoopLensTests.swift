//
//  LoopLensTests.swift
//  LoopLensTests
//
//  Created by Danilo Lekovic on 2026-10-13.
//

import CoreGraphics
import Foundation
import Testing
@testable import LoopLens

struct LoopLensTests {
    private let display = CaptureDisplay(
        id: 1,
        name: "Studio Display",
        width: 5120,
        height: 2880,
        frame: CGRect(x: 0, y: 0, width: 2560, height: 1440)
    )

    @Test func resolutionLabelUsesPixelDimensions() {
        #expect(display.resolutionLabel == "5120 × 2880")
    }

    @Test func previewSizePreservesAspectRatio() {
        #expect(display.previewSize(maxDimension: 1600) == CGSize(width: 1600, height: 900))
    }

    @Test func previewSizeDoesNotUpscaleSmallDisplays() {
        let smallDisplay = CaptureDisplay(
            id: 2,
            name: "Small Display",
            width: 1280,
            height: 720,
            frame: CGRect(x: 0, y: 0, width: 1280, height: 720)
        )

        #expect(smallDisplay.previewSize(maxDimension: 1600) == CGSize(width: 1280, height: 720))
    }

    @Test func captureRegionConvertsFromAppKitCoordinates() {
        let region = CaptureRegion(
            appKitRect: CGRect(x: 100, y: 200, width: 800, height: 450),
            displayHeight: 1080
        )

        #expect(region.rect == CGRect(x: 100, y: 430, width: 800, height: 450))
        #expect(
            region.appKitRect(displayHeight: 1080)
                == CGRect(x: 100, y: 200, width: 800, height: 450)
        )
    }

    @Test func captureRegionUsesRetinaScaleAndMaximumDimension() {
        let region = CaptureRegion(
            appKitRect: CGRect(x: 0, y: 0, width: 1200, height: 800),
            displayHeight: 1080
        )

        #expect(
            region.outputSize(backingScaleFactor: 2, maxDimension: 1920)
                == CGSize(width: 1920, height: 1280)
        )
    }

    @Test func gifSettingsCalculateTimingAndFrameCount() {
        let settings = GIFExportSettings(framesPerSecond: 15, maxDimension: 960)

        #expect(settings.frameDelay == 1.0 / 15.0)
        #expect(settings.frameCount(durationSeconds: 2.9) == 43)
        #expect(settings.frameCount(durationSeconds: 0.01) == 1)
    }

    @Test @MainActor func recordingNameIsSafeForSavePanels() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = ScreenCaptureStore(defaults: defaults)

        store.recordingName = "  Product / Demo: Final  "
        #expect(store.safeRecordingName == "Product - Demo- Final")

        store.recordingName = "   "
        #expect(store.safeRecordingName == "LoopLens Recording")
    }

    @Test @MainActor func recordingPreferencesPersist() {
        let suiteName = #function
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let store = ScreenCaptureStore(defaults: defaults)
        store.usesRecordingFloaty = false
        store.excludesLoopLensFromCapture = false

        let restoredStore = ScreenCaptureStore(defaults: defaults)
        #expect(restoredStore.usesRecordingFloaty == false)
        #expect(restoredStore.excludesLoopLensFromCapture == false)
    }

    @Test func outputFolderUsesCollisionSafeNames() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let existingURL = folder.appendingPathComponent("Demo.gif")
        _ = FileManager.default.createFile(atPath: existingURL.path, contents: Data())
        let manager = OutputFolderManager(defaults: UserDefaults.standard)

        #expect(manager.availableURL(for: "Demo", in: folder).lastPathComponent == "Demo 2.gif")
    }

    @Test func cursorCircleRecognizerDetectsRepeatedRotation() {
        var recognizer = CursorCircleRecognizer()
        let start = Date(timeIntervalSince1970: 1_000)
        var detectedCircle: CGRect?

        for index in 0..<72 {
            let angle = CGFloat(index) / 72 * 4 * .pi
            let point = CGPoint(
                x: 240 + cos(angle) * 64,
                y: 180 + sin(angle) * 64
            )
            detectedCircle = recognizer.add(
                point,
                at: start.addingTimeInterval(Double(index) * 0.012)
            ) ?? detectedCircle
        }

        #expect(detectedCircle != nil)
        #expect(abs((detectedCircle?.midX ?? 0) - 240) < 8)
        #expect(abs((detectedCircle?.midY ?? 0) - 180) < 8)
    }
}
