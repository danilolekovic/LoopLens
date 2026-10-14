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
        precondition(maxDimension > 0)
        let longestEdge = max(width, height)
        guard longestEdge > maxDimension else {
            return CGSize(width: width, height: height)
        }

        let scale = CGFloat(maxDimension) / CGFloat(longestEdge)
        return CGSize(
            width: Int(CGFloat(width) * scale),
            height: Int(CGFloat(height) * scale)
        )
    }
}
