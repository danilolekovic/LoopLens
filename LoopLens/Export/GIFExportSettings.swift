import Foundation

struct GIFExportSettings: Equatable, Sendable {
    var framesPerSecond: Int = 15
    var maxDimension: Int = 960

    var frameDelay: Double {
        1 / Double(framesPerSecond)
    }

    func frameCount(durationSeconds: Double) -> Int {
        max(1, Int(floor(durationSeconds * Double(framesPerSecond))))
    }
}
