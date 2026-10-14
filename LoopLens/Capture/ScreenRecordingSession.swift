import AVFoundation
import CoreMedia
import CoreVideo
import Foundation
import ScreenCaptureKit

final class ScreenRecordingSession: NSObject, SCStreamOutput, SCStreamDelegate {
    enum RecordingError: LocalizedError {
        case cannotAddWriterInput
        case noVideoFrames
        case writerFailed(String)

        var errorDescription: String? {
            switch self {
            case .cannotAddWriterInput:
                "LoopLens could not configure the video encoder."
            case .noVideoFrames:
                "The recording ended before LoopLens received a video frame."
            case let .writerFailed(message):
                "The video encoder stopped: \(message)"
            }
        }
    }

    let outputURL: URL

    private let videoQueue = DispatchQueue(label: "ca.danilolekovic.LoopLens.video")
    private var stream: SCStream?
    private var writer: AVAssetWriter?
    private var writerInput: AVAssetWriterInput?
    private var hasStartedWriting = false
    private var streamError: Error?

    init(outputURL: URL) {
        self.outputURL = outputURL
        super.init()
    }

    func start(filter: SCContentFilter, configuration: SCStreamConfiguration) async throws {
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: configuration.width,
                AVVideoHeightKey: configuration.height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 8_000_000,
                    AVVideoExpectedSourceFrameRateKey: 30,
                    AVVideoMaxKeyFrameIntervalKey: 60,
                ],
            ]
        )
        input.expectsMediaDataInRealTime = true

        guard writer.canAdd(input) else {
            throw RecordingError.cannotAddWriterInput
        }
        writer.add(input)

        self.writer = writer
        writerInput = input

        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: videoQueue)
        self.stream = stream
        try await stream.startCapture()
    }

    func stop() async throws -> URL {
        try await stream?.stopCapture()
        stream = nil

        await withCheckedContinuation { continuation in
            videoQueue.async { [self] in
                guard let writer, let writerInput else {
                    continuation.resume()
                    return
                }

                writerInput.markAsFinished()
                writer.finishWriting {
                    continuation.resume()
                }
            }
        }

        if let streamError {
            throw streamError
        }
        guard hasStartedWriting else {
            throw RecordingError.noVideoFrames
        }
        if let error = writer?.error {
            throw RecordingError.writerFailed(error.localizedDescription)
        }
        return outputURL
    }

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        guard
            outputType == .screen,
            sampleBuffer.isValid,
            let writer,
            let writerInput
        else {
            return
        }

        if !hasStartedWriting {
            guard writer.startWriting() else { return }
            writer.startSession(atSourceTime: sampleBuffer.presentationTimeStamp)
            hasStartedWriting = true
        }

        if writerInput.isReadyForMoreMediaData {
            writerInput.append(sampleBuffer)
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: any Error) {
        videoQueue.async { [weak self] in
            self?.streamError = error
        }
    }
}
