import CoreGraphics
import Foundation

// Finds the point and direction at a distance along a path, measured over a flattened copy. A move between
// subpaths adds no distance.
struct PathWalker {
    private struct Segment {
        var from: CGPoint
        var to: CGPoint
        // Distance along the path where this segment starts.
        var start: Double
        var length: Double
    }

    private let segments: [Segment]
    let length: Double

    init(_ path: CGPath, flatness: Double = 0.05) {
        var segments: [Segment] = []
        var total = 0.0
        var current = CGPoint.zero
        var subpathStart = CGPoint.zero
        func line(to point: CGPoint) {
            let length = hypot(point.x - current.x, point.y - current.y)
            if length > 0 {
                segments.append(Segment(from: current, to: point, start: total, length: length))
                total += length
            }
            current = point
        }
        path.flattened(threshold: flatness).applyWithBlock { element in
            let points = element.pointee.points
            switch element.pointee.type {
            case .moveToPoint:
                current = points[0]
                subpathStart = points[0]
            case .addLineToPoint:
                line(to: points[0])
            case .closeSubpath:
                line(to: subpathStart)
            case .addQuadCurveToPoint:
                line(to: points[1])
            case .addCurveToPoint:
                line(to: points[2])
            @unknown default:
                break
            }
        }
        self.segments = segments
        length = total
    }

    // Nil off either end of the path.
    func place(at distance: Double) -> (point: CGPoint, angle: Double)? {
        guard distance >= 0, distance <= length else {
            return nil
        }
        // Segments are in order of distance, so search for the last one starting at or before it.
        var low = 0
        var high = segments.count - 1
        while low < high {
            let middle = (low + high + 1) / 2
            if segments[middle].start <= distance {
                low = middle
            } else {
                high = middle - 1
            }
        }
        guard segments.indices.contains(low) else {
            return nil
        }
        let segment = segments[low]
        let fraction = min(1, (distance - segment.start) / segment.length)
        let point = CGPoint(x: segment.from.x + (segment.to.x - segment.from.x) * fraction, y: segment.from.y + (segment.to.y - segment.from.y) * fraction)
        return (point, atan2(segment.to.y - segment.from.y, segment.to.x - segment.from.x))
    }
}
