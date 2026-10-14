import CoreGraphics

struct CaptureDisplay: Identifiable, Hashable, Sendable {
    let id: CGDirectDisplayID
    let name: String
    let width: Int
    let height: Int
    let frame: CGRect

    var resolutionLabel: String {
        "\(width) × \(height)"
    }

    func previewSize(maxDimension: Int) -> CGSize {
        CGSize(width: width, height: height).scaledToFit(maxDimension: maxDimension)
    }
}
