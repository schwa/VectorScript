import Foundation

public enum MarkerOrientation: Sendable, Equatable, Codable {
    // Along the path; at middle vertices, halfway between the incoming and outgoing directions.
    case auto
    // As auto, but the start marker points backwards, so one arrow shape works at both ends.
    case autoStartReverse
    // A fixed angle in degrees, clockwise.
    case angle(Double)

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let degrees = try? container.decode(Double.self) {
            self = .angle(degrees)
            return
        }
        switch try container.decode(String.self) {
        case "auto":
            self = .auto
        case "auto-start-reverse":
            self = .autoStartReverse
        case let other:
            throw decoder.corrupted("unknown orient '\(other)' (expected auto, auto-start-reverse or a number)")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .auto: try container.encode("auto")
        case .autoStartReverse: try container.encode("auto-start-reverse")
        case .angle(let degrees): try container.encode(degrees)
        }
    }
}

// Drawn at the vertices of a path, line, polyline or polygon, with its origin on the vertex. Units are user units.
public struct Marker: Sendable, Equatable, Codable {
    public indirect enum Source: Sendable, Equatable {
        // Cancels an inherited marker.
        case none
        // An element in the document's defs.
        case named(String)
        case element(Element)
    }

    public var source: Source
    public var orientation: MarkerOrientation

    public init(_ source: Source, orientation: MarkerOrientation = .auto) {
        self.source = source
        self.orientation = orientation
    }

    public init(from decoder: any Decoder) throws {
        if let name = try? decoder.singleValueContainer().decode(String.self) {
            source = name == "none" ? .none : .named(name)
            orientation = .auto
            return
        }
        let container = try decoder.container(keyedBy: AnyKey.self)
        let type = try container.singleKey(from: ["name", "element"], what: "a marker")
        try container.rejectUnknownKeys(allowed: [type, "orient"])
        orientation = try container.decodeIfPresent(MarkerOrientation.self, "orient") ?? .auto
        source = type == "name" ? .named(try container.decode(String.self, type)) : .element(try container.decode(Element.self, type))
    }

    public func encode(to encoder: any Encoder) throws {
        switch source {
        case .none:
            var container = encoder.singleValueContainer()
            try container.encode("none")
        case .named(let name) where orientation == .auto:
            var container = encoder.singleValueContainer()
            try container.encode(name)
        case .named(let name):
            var container = encoder.container(keyedBy: AnyKey.self)
            try container.encode(name, "name")
            try container.encode(orientation, "orient")
        case .element(let element):
            var container = encoder.container(keyedBy: AnyKey.self)
            try container.encode(element, "element")
            if orientation != .auto {
                try container.encode(orientation, "orient")
            }
        }
    }
}

// Where markers go on a shape: each vertex with its angle in degrees.
public struct MarkerVertex: Sendable, Equatable {
    public enum Position: Sendable, Equatable {
        case start, mid, end
    }

    public var point: Point
    // Clockwise degrees: the incoming direction, the outgoing direction, or halfway between them.
    public var angle: Double
    public var position: Position
}

public extension Shape {
    // Whether markers apply, as in SVG.
    var takesMarkers: Bool {
        switch self {
        case .path, .line, .polyline, .polygon: true
        case .rect, .circle, .ellipse: false
        }
    }

    var markerVertices: [MarkerVertex] {
        let segments: [PathSegment]
        switch self {
        case .path(let data):
            segments = data.segments
        case .line(let from, let to):
            segments = [.move(to: from), .line(to: to)]
        case .polyline(let points), .polygon(let points):
            guard let first = points.first else {
                return []
            }
            segments = [.move(to: first)] + points.dropFirst().map { .line(to: $0) } + (isPolygon ? [.close] : [])
        case .rect, .circle, .ellipse:
            return []
        }
        return Self.vertices(of: segments)
    }

    private var isPolygon: Bool {
        if case .polygon = self {
            return true
        }
        return false
    }

    // One vertex per segment end, with the direction a segment leaves its start and arrives at its end.
    private static func vertices(of segments: [PathSegment]) -> [MarkerVertex] {
        struct Raw {
            var point: Point
            var incoming: Double?
            var outgoing: Double?
        }
        func angle(from a: Point, to b: Point) -> Double? {
            guard a != b else {
                return nil
            }
            return atan2(b.y - a.y, b.x - a.x) * 180 / .pi
        }
        var raws: [Raw] = []
        var current = Point.zero
        var subpathStart = Point.zero
        for segment in segments {
            var directions: (out: Double?, in: Double?)
            var end: Point
            switch segment {
            case .move(let to):
                current = to
                subpathStart = to
                raws.append(Raw(point: to))
                continue
            case .line(let to):
                end = to
                directions = (angle(from: current, to: to), angle(from: current, to: to))
            case .quadratic(let control, let to):
                end = to
                directions = (angle(from: current, to: control) ?? angle(from: current, to: to), angle(from: control, to: to) ?? angle(from: current, to: to))
            case .cubic(let control1, let control2, let to):
                end = to
                directions = (angle(from: current, to: control1) ?? angle(from: current, to: control2) ?? angle(from: current, to: to), angle(from: control2, to: to) ?? angle(from: control1, to: to) ?? angle(from: current, to: to))
            case .arc(let radii, let rotation, let largeArc, let sweep, let to):
                end = to
                let curves = PathSegment.arcCurves(from: current, radii: radii, rotation: rotation, largeArc: largeArc, sweep: sweep, to: to)
                let first = curves.first
                let last = curves.last
                let lastStart = curves.count > 1 ? curves[curves.count - 2].to : current
                directions = (first.flatMap { angle(from: current, to: $0.control1) } ?? angle(from: current, to: to), last.flatMap { angle(from: $0.control2, to: to) ?? angle(from: lastStart, to: to) } ?? angle(from: current, to: to))
            case .close:
                end = subpathStart
                directions = (angle(from: current, to: subpathStart), angle(from: current, to: subpathStart))
            }
            if !raws.isEmpty {
                raws[raws.count - 1].outgoing = raws[raws.count - 1].outgoing ?? directions.out
            }
            raws.append(Raw(point: end, incoming: directions.in))
            current = end
        }
        return raws.enumerated().map { index, raw in
            let position: MarkerVertex.Position = index == 0 ? .start : (index == raws.count - 1 ? .end : .mid)
            let incoming = raw.incoming ?? raw.outgoing ?? 0
            let outgoing = raw.outgoing ?? raw.incoming ?? 0
            let angle: Double
            switch position {
            case .start: angle = outgoing
            case .end: angle = incoming
            case .mid:
                // Halfway between, taking the short way round.
                var difference = outgoing - incoming
                difference -= 360 * (difference / 360).rounded()
                angle = incoming + difference / 2
            }
            return MarkerVertex(point: raw.point, angle: angle, position: position)
        }
    }
}
