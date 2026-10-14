//
//  LoopLensTests.swift
//  LoopLensTests
//
//  Created by Danilo Lekovic on 2026-10-13.
//

import CoreGraphics
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
}
