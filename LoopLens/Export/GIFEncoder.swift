import AVFoundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

actor GIFEncoder {
    enum EncodingError: LocalizedError {
        case invalidDuration
        case cannotCreateDestination
        case cannotFinalize

        var errorDescription: String? {
            switch self {
            case .invalidDuration:
                "The recording has no usable video duration."
            case .cannotCreateDestination:
                "LoopLens could not create the GIF file."
            case .cannotFinalize:
                "LoopLens could not finish writing the GIF file."
            }
        }
    }

    func encode(
        sourceURL: URL,
        destinationURL: URL,
        settings: GIFExportSettings,
        progress: @MainActor @escaping @Sendable (Double) -> Void
    ) async throws {
        let asset = AVURLAsset(url: sourceURL)
        let duration = try await asset.load(.duration)
        let durationSeconds = duration.seconds
        guard durationSeconds.isFinite, durationSeconds > 0 else {
            throw EncodingError.invalidDuration
        }

        let frameDelay = await settings.frameDelay
        let maxDimension = settings.maxDimension
        let frameCount = await settings.frameCount(durationSeconds: durationSeconds)
        guard let destination = CGImageDestinationCreateWithURL(
            destinationURL as CFURL,
            UTType.gif.identifier as CFString,
            frameCount,
            nil
        ) else {
            throw EncodingError.cannotCreateDestination
        }

        let destinationProperties: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFLoopCount: 0,
            ],
        ]
        CGImageDestinationSetProperties(destination, destinationProperties as CFDictionary)

        let frameProperties: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFDelayTime: frameDelay,
                kCGImagePropertyGIFUnclampedDelayTime: frameDelay,
            ],
        ]

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(
            width: maxDimension,
            height: maxDimension
        )
        let halfFrame = CMTime(
            seconds: frameDelay / 2,
            preferredTimescale: 600
        )
        generator.requestedTimeToleranceBefore = halfFrame
        generator.requestedTimeToleranceAfter = halfFrame

        for frameIndex in 0..<frameCount {
            try Task.checkCancellation()
            let time = CMTime(
                seconds: Double(frameIndex) * frameDelay,
                preferredTimescale: 600
            )
            let (image, _) = try await generator.image(at: time)
            CGImageDestinationAddImage(destination, image, frameProperties as CFDictionary)
            await progress(Double(frameIndex + 1) / Double(frameCount))
        }

        guard CGImageDestinationFinalize(destination) else {
            throw EncodingError.cannotFinalize
        }
    }
}
