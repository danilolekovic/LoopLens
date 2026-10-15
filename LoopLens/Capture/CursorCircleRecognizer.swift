import CoreGraphics
import Foundation

struct CursorCircleRecognizer {
    private struct Sample {
        let point: CGPoint
        let date: Date
    }

    private var samples: [Sample] = []

    mutating func add(_ point: CGPoint, at date: Date = .now) -> CGRect? {
        samples.append(Sample(point: point, date: date))
        samples.removeAll { date.timeIntervalSince($0.date) > 1.4 }
        guard samples.count >= 24 else { return nil }

        let points = samples.map(\.point)
        let bounds = points.reduce(CGRect.null) { $0.union(CGRect(origin: $1, size: .zero)) }
        let diameter = max(bounds.width, bounds.height)
        guard diameter >= 28, diameter <= 480 else { return nil }

        let aspectRatio = bounds.width / max(bounds.height, 1)
        guard (0.55...1.8).contains(aspectRatio) else { return nil }

        let center = CGPoint(
            x: points.map(\.x).reduce(0, +) / CGFloat(points.count),
            y: points.map(\.y).reduce(0, +) / CGFloat(points.count)
        )
        let radii = points.map { hypot($0.x - center.x, $0.y - center.y) }
        let meanRadius = radii.reduce(0, +) / CGFloat(radii.count)
        guard meanRadius >= 14 else { return nil }

        let meanDeviation = radii.map { abs($0 - meanRadius) }.reduce(0, +) / CGFloat(radii.count)
        guard meanDeviation / meanRadius < 0.34 else { return nil }

        let angles = points.map { atan2($0.y - center.y, $0.x - center.x) }
        var signedRotation: CGFloat = 0
        var absoluteRotation: CGFloat = 0
        for index in 1..<angles.count {
            var delta = angles[index] - angles[index - 1]
            while delta > .pi { delta -= 2 * .pi }
            while delta < -.pi { delta += 2 * .pi }
            signedRotation += delta
            absoluteRotation += abs(delta)
        }

        guard
            abs(signedRotation) >= 1.55 * 2 * .pi,
            abs(signedRotation) / max(absoluteRotation, 0.001) > 0.7
        else {
            return nil
        }

        samples.removeAll()
        let paddedDiameter = diameter + 18
        return CGRect(
            x: bounds.midX - paddedDiameter / 2,
            y: bounds.midY - paddedDiameter / 2,
            width: paddedDiameter,
            height: paddedDiameter
        )
    }
}
