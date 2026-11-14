import Foundation

// One step of a path, in absolute coordinates.
public enum PathSegment: Sendable, Equatable {
    case move(to: Point)
    case line(to: Point)
    case quadratic(control: Point, to: Point)
    case cubic(control1: Point, control2: Point, to: Point)
    // An SVG elliptical arc; `rotation` is in degrees.
    case arc(radii: Size, rotation: Double, largeArc: Bool, sweep: Bool, to: Point)
    case close
}

public enum PathError: Error, Equatable, CustomStringConvertible {
    case syntax(reason: String, offset: Int)

    public var description: String {
        switch self {
        case .syntax(let reason, let offset): "bad path: \(reason) at offset \(offset)"
        }
    }
}

public struct PathData: Sendable, Equatable, Codable {
    public var segments: [PathSegment]

    public init(_ segments: [PathSegment]) {
        self.segments = segments
    }

    // SVG path data: M L H V C S Q T A Z, absolute or relative, with implicit repeats.
    public init(parsing text: String) throws(PathError) {
        var parser = PathParser(text)
        segments = try parser.parse()
    }

    // SVG path data with absolute commands only.
    public var string: String {
        segments.map { segment in
            switch segment {
            case .move(let to):
                "M \(Self.format(to))"
            case .line(let to):
                "L \(Self.format(to))"
            case .quadratic(let control, let to):
                "Q \(Self.format(control)) \(Self.format(to))"
            case .cubic(let control1, let control2, let to):
                "C \(Self.format(control1)) \(Self.format(control2)) \(Self.format(to))"
            case .arc(let radii, let rotation, let largeArc, let sweep, let to):
                "A \(formatNumber(radii.width)) \(formatNumber(radii.height)) \(formatNumber(rotation)) \(largeArc ? 1 : 0) \(sweep ? 1 : 0) \(Self.format(to))"
            case .close:
                "Z"
            }
        }.joined(separator: " ")
    }

    private static func format(_ point: Point) -> String {
        "\(formatNumber(point.x)) \(formatNumber(point.y))"
    }

    public init(from decoder: any Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        do {
            try self.init(parsing: text)
        } catch {
            throw decoder.corrupted(error.description)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(string)
    }
}

struct PathParser {
    private var scanner: NumberScanner
    private var current = Point.zero
    private var subpathStart = Point.zero
    // The last control point, for S and T to reflect.
    private var lastCubicControl: Point?
    private var lastQuadraticControl: Point?

    init(_ text: String) {
        scanner = NumberScanner(text)
    }

    mutating func parse() throws(PathError) -> [PathSegment] {
        var segments: [PathSegment] = []
        var command: Character?
        while !scanner.isAtEnd {
            if let letter = scanner.letter() {
                guard "MmLlHhVvCcSsQqTtAaZz".contains(letter) else {
                    throw failure("unknown command '\(letter)'")
                }
                guard !segments.isEmpty || letter == "M" || letter == "m" else {
                    throw failure("a path starts with M")
                }
                command = letter
                if letter == "Z" || letter == "z" {
                    segments.append(.close)
                    current = subpathStart
                    lastCubicControl = nil
                    lastQuadraticControl = nil
                    continue
                }
            }
            guard let active = command, active != "Z", active != "z" else {
                throw failure("expected a command")
            }
            segments.append(try segment(for: active))
            if active == "M" {
                command = "L"
            } else if active == "m" {
                command = "l"
            }
        }
        return segments
    }

    private func failure(_ reason: String) -> PathError {
        .syntax(reason: reason, offset: scanner.index)
    }

    private mutating func number() throws(PathError) -> Double {
        guard let value = scanner.number() else {
            throw failure("expected a number")
        }
        return value
    }

    private mutating func flag() throws(PathError) -> Bool {
        guard let value = scanner.flag() else {
            throw failure("expected an arc flag (0 or 1)")
        }
        return value
    }

    private mutating func point(relative: Bool) throws(PathError) -> Point {
        let x = try number()
        let y = try number()
        return relative ? Point(x: current.x + x, y: current.y + y) : Point(x: x, y: y)
    }

    private mutating func segment(for command: Character) throws(PathError) -> PathSegment {
        let relative = command.isLowercase
        var cubicControl: Point?
        var quadraticControl: Point?
        let result: PathSegment
        switch command.uppercased() {
        case "M":
            let to = try point(relative: relative)
            subpathStart = to
            current = to
            result = .move(to: to)
        case "L":
            current = try point(relative: relative)
            result = .line(to: current)
        case "H":
            let x = try number()
            current = Point(x: relative ? current.x + x : x, y: current.y)
            result = .line(to: current)
        case "V":
            let y = try number()
            current = Point(x: current.x, y: relative ? current.y + y : y)
            result = .line(to: current)
        case "C":
            let control1 = try point(relative: relative)
            let control2 = try point(relative: relative)
            let to = try point(relative: relative)
            cubicControl = control2
            current = to
            result = .cubic(control1: control1, control2: control2, to: to)
        case "S":
            let control1 = reflect(lastCubicControl)
            let control2 = try point(relative: relative)
            let to = try point(relative: relative)
            cubicControl = control2
            current = to
            result = .cubic(control1: control1, control2: control2, to: to)
        case "Q":
            let control = try point(relative: relative)
            let to = try point(relative: relative)
            quadraticControl = control
            current = to
            result = .quadratic(control: control, to: to)
        case "T":
            let control = reflect(lastQuadraticControl)
            let to = try point(relative: relative)
            quadraticControl = control
            current = to
            result = .quadratic(control: control, to: to)
        default:
            let radii = Size(width: abs(try number()), height: abs(try number()))
            let rotation = try number()
            let largeArc = try flag()
            let sweep = try flag()
            let to = try point(relative: relative)
            current = to
            result = radii.width == 0 || radii.height == 0 ? .line(to: to) : .arc(radii: radii, rotation: rotation, largeArc: largeArc, sweep: sweep, to: to)
        }
        lastCubicControl = cubicControl
        lastQuadraticControl = quadraticControl
        return result
    }

    // The previous control point mirrored through the current point; the current point when there is none.
    private func reflect(_ control: Point?) -> Point {
        guard let control else {
            return current
        }
        return Point(x: 2 * current.x - control.x, y: 2 * current.y - control.y)
    }
}
