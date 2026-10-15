import CoreGraphics

enum PlaybackLayout {
    static let maximumSize = CGSize(width: 640, height: 480)
    static let padding: CGFloat = 64

    static func size(aspectRatio: CGFloat, availableSize: CGSize) -> CGSize {
        let ratio = max(aspectRatio, 0.01)
        let availableWidth = max(1, availableSize.width - padding)
        let availableHeight = max(1, availableSize.height - padding)
        let widthLimit = min(maximumSize.width, availableWidth)
        let heightLimit = min(maximumSize.height, availableHeight)

        if widthLimit / heightLimit > ratio {
            return CGSize(width: heightLimit * ratio, height: heightLimit)
        }
        return CGSize(width: widthLimit, height: widthLimit / ratio)
    }
}
