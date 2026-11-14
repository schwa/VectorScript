import CoreGraphics
import VectorScript

extension Point {
    var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }
}

extension Matrix {
    var cgAffineTransform: CGAffineTransform {
        CGAffineTransform(a: a, b: b, c: c, d: d, tx: tx, ty: ty)
    }
}

extension Color {
    var cgColor: CGColor {
        CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }
}

extension FillRule {
    var cgFillRule: CGPathFillRule {
        self == .evenodd ? .evenOdd : .winding
    }
}

extension StrokeCap {
    var cgLineCap: CGLineCap {
        switch self {
        case .butt: .butt
        case .round: .round
        case .square: .square
        }
    }
}

extension StrokeJoin {
    var cgLineJoin: CGLineJoin {
        switch self {
        case .miter: .miter
        case .round: .round
        case .bevel: .bevel
        }
    }
}

public extension Shape {
    var cgPath: CGPath {
        let path = CGMutablePath()
        switch self {
        case .rect(let rect, let cornerRadius):
            let cgRect = CGRect(x: rect.origin.x, y: rect.origin.y, width: rect.size.width, height: rect.size.height)
            if let cornerRadius, cornerRadius.width > 0, cornerRadius.height > 0 {
                path.addRoundedRect(in: cgRect, cornerWidth: min(cornerRadius.width, cgRect.width / 2), cornerHeight: min(cornerRadius.height, cgRect.height / 2))
            } else {
                path.addRect(cgRect)
            }
        case .circle(let center, let radius):
            path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        case .ellipse(let center, let radii):
            path.addEllipse(in: CGRect(x: center.x - radii.width, y: center.y - radii.height, width: radii.width * 2, height: radii.height * 2))
        case .line(let from, let to):
            path.move(to: from.cgPoint)
            path.addLine(to: to.cgPoint)
        case .polyline(let points), .polygon(let points):
            guard let first = points.first else {
                break
            }
            path.move(to: first.cgPoint)
            for point in points.dropFirst() {
                path.addLine(to: point.cgPoint)
            }
            if case .polygon = self {
                path.closeSubpath()
            }
        case .path(let data):
            data.add(to: path)
        }
        return path
    }
}

extension PathData {
    func add(to path: CGMutablePath) {
        var current = Point.zero
        var subpathStart = Point.zero
        for segment in segments {
            switch segment {
            case .move(let to):
                path.move(to: to.cgPoint)
                current = to
                subpathStart = to
            case .line(let to):
                path.addLine(to: to.cgPoint)
                current = to
            case .quadratic(let control, let to):
                path.addQuadCurve(to: to.cgPoint, control: control.cgPoint)
                current = to
            case .cubic(let control1, let control2, let to):
                path.addCurve(to: to.cgPoint, control1: control1.cgPoint, control2: control2.cgPoint)
                current = to
            case .arc(let radii, let rotation, let largeArc, let sweep, let to):
                for curve in PathSegment.arcCurves(from: current, radii: radii, rotation: rotation, largeArc: largeArc, sweep: sweep, to: to) {
                    path.addCurve(to: curve.to.cgPoint, control1: curve.control1.cgPoint, control2: curve.control2.cgPoint)
                }
                current = to
            case .close:
                path.closeSubpath()
                current = subpathStart
            }
        }
    }
}
