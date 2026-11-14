public struct GradientStop: Sendable, Equatable, Codable {
    // 0...1
    public var offset: Double
    public var color: Color

    public init(offset: Double, color: Color) {
        self.offset = offset
        self.color = color
    }

    public init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        offset = try container.decode(Double.self)
        color = try container.decode(Color.self)
        guard container.isAtEnd else {
            throw decoder.corrupted("a stop is [offset, color]")
        }
        guard (0...1).contains(offset) else {
            throw decoder.corrupted("stop offset \(formatNumber(offset)) is outside 0...1")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(offset)
        try container.encode(color)
    }
}

public enum GradientUnits: String, Sendable, Equatable, Codable {
    // Coordinates are fractions of the painted shape's bounding box.
    case boundingBox
    // Coordinates are in the element's user space.
    case user
}

public struct LinearGradient: Sendable, Equatable, Codable {
    public var from: Point
    public var to: Point
    public var stops: [GradientStop]
    public var units: GradientUnits

    public init(from: Point = Point(x: 0, y: 0), to: Point = Point(x: 1, y: 0), stops: [GradientStop], units: GradientUnits = .boundingBox) {
        self.from = from
        self.to = to
        self.stops = stops
        self.units = units
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: AnyKey.self)
        try container.rejectUnknownKeys(allowed: ["from", "to", "stops", "units"])
        from = try container.decodeIfPresent(Point.self, "from") ?? Point(x: 0, y: 0)
        to = try container.decodeIfPresent(Point.self, "to") ?? Point(x: 1, y: 0)
        stops = try container.decode([GradientStop].self, "stops")
        units = try container.decodeIfPresent(GradientUnits.self, "units") ?? .boundingBox
        guard !stops.isEmpty else {
            throw container.corrupted("a gradient needs at least one stop")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: AnyKey.self)
        try container.encode(from, "from")
        try container.encode(to, "to")
        try container.encode(stops, "stops")
        if units != .boundingBox {
            try container.encode(units, "units")
        }
    }
}

public struct RadialGradient: Sendable, Equatable, Codable {
    public var center: Point
    public var radius: Double
    // Where the first stop's color sits; the center when nil.
    public var focus: Point?
    public var stops: [GradientStop]
    public var units: GradientUnits

    public init(center: Point = Point(x: 0.5, y: 0.5), radius: Double = 0.5, focus: Point? = nil, stops: [GradientStop], units: GradientUnits = .boundingBox) {
        self.center = center
        self.radius = radius
        self.focus = focus
        self.stops = stops
        self.units = units
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: AnyKey.self)
        try container.rejectUnknownKeys(allowed: ["center", "radius", "focus", "stops", "units"])
        center = try container.decodeIfPresent(Point.self, "center") ?? Point(x: 0.5, y: 0.5)
        radius = try container.decodeIfPresent(Double.self, "radius") ?? 0.5
        focus = try container.decodeIfPresent(Point.self, "focus")
        stops = try container.decode([GradientStop].self, "stops")
        units = try container.decodeIfPresent(GradientUnits.self, "units") ?? .boundingBox
        guard !stops.isEmpty else {
            throw container.corrupted("a gradient needs at least one stop")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: AnyKey.self)
        try container.encode(center, "center")
        try container.encode(radius, "radius")
        try container.encodeIfPresent(focus, "focus")
        try container.encode(stops, "stops")
        if units != .boundingBox {
            try container.encode(units, "units")
        }
    }
}
