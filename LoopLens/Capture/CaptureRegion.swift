import CoreGraphics

struct CaptureRegion: Equatable, Sendable {
    let rect: CGRect

    init(appKitRect: CGRect, displayHeight: CGFloat) {
        let rect = appKitRect.standardized
        self.rect = CGRect(
            x: rect.minX,
            y: displayHeight - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    var sizeLabel: String {
        "\(Int(rect.width)) × \(Int(rect.height)) pt"
    }

    func outputSize(backingScaleFactor: CGFloat, maxDimension: Int) -> CGSize {
        let pixelSize = CGSize(
            width: rect.width * backingScaleFactor,
            height: rect.height * backingScaleFactor
        )
        return pixelSize.scaledToFit(maxDimension: maxDimension)
    }
}

extension CGSize {
    func scaledToFit(maxDimension: Int) -> CGSize {
        precondition(maxDimension > 0)
        let longestEdge = max(width, height)
        guard longestEdge > CGFloat(maxDimension) else { return self }

        let scale = CGFloat(maxDimension) / longestEdge
        return CGSize(
            width: floor(width * scale),
            height: floor(height * scale)
        )
    }
}
