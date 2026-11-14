import Foundation

public struct CubicCurve: Sendable, Equatable {
    public var control1: Point
    public var control2: Point
    public var to: Point
}

public extension PathSegment {
    // Cubic curves that trace an SVG arc from `start`. See SVG 1.1 appendix F.6.5.
    static func arcCurves(from start: Point, radii: Size, rotation: Double, largeArc: Bool, sweep: Bool, to end: Point) -> [CubicCurve] {
        guard start != end else {
            return []
        }
        var rx = abs(radii.width)
        var ry = abs(radii.height)
        guard rx > 0, ry > 0 else {
            return [CubicCurve(control1: start, control2: end, to: end)]
        }
        let phi = rotation * .pi / 180
        let cosPhi = cos(phi)
        let sinPhi = sin(phi)
        let halfX = (start.x - end.x) / 2
        let halfY = (start.y - end.y) / 2
        let x1 = cosPhi * halfX + sinPhi * halfY
        let y1 = -sinPhi * halfX + cosPhi * halfY

        let lambda = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
        if lambda > 1 {
            rx *= lambda.squareRoot()
            ry *= lambda.squareRoot()
        }
        let numerator = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
        let denominator = rx * rx * y1 * y1 + ry * ry * x1 * x1
        let coefficient = (largeArc != sweep ? 1.0 : -1.0) * max(0, numerator / denominator).squareRoot()
        let centerX1 = coefficient * (rx * y1 / ry)
        let centerY1 = coefficient * -(ry * x1 / rx)
        let centerX = cosPhi * centerX1 - sinPhi * centerY1 + (start.x + end.x) / 2
        let centerY = sinPhi * centerX1 + cosPhi * centerY1 + (start.y + end.y) / 2

        func angle(_ ux: Double, _ uy: Double, _ vx: Double, _ vy: Double) -> Double {
            atan2(ux * vy - uy * vx, ux * vx + uy * vy)
        }
        let startX = (x1 - centerX1) / rx
        let startY = (y1 - centerY1) / ry
        let theta = angle(1, 0, startX, startY)
        var delta = angle(startX, startY, (-x1 - centerX1) / rx, (-y1 - centerY1) / ry)
        if !sweep, delta > 0 {
            delta -= 2 * .pi
        } else if sweep, delta < 0 {
            delta += 2 * .pi
        }

        let count = max(1, Int((abs(delta) / (.pi / 2) - 1e-9).rounded(.up)))
        let step = delta / Double(count)
        let handle = 4.0 / 3.0 * tan(step / 4)
        func place(_ x: Double, _ y: Double) -> Point {
            Point(x: centerX + rx * x * cosPhi - ry * y * sinPhi, y: centerY + rx * x * sinPhi + ry * y * cosPhi)
        }
        return (0..<count).map { index in
            let a1 = theta + Double(index) * step
            let a2 = a1 + step
            return CubicCurve(
                control1: place(cos(a1) - handle * sin(a1), sin(a1) + handle * cos(a1)),
                control2: place(cos(a2) + handle * sin(a2), sin(a2) - handle * cos(a2)),
                to: index == count - 1 ? end : place(cos(a2), sin(a2))
            )
        }
    }
}
