public enum Shape: Sendable, Equatable {
    case rect(Rect, cornerRadius: Size?)
    case circle(center: Point, radius: Double)
    case ellipse(center: Point, radii: Size)
    case line(from: Point, to: Point)
    case polyline([Point])
    case polygon([Point])
    case path(PathData)

    static let typeKeys: Set<String> = ["rect", "circle", "ellipse", "line", "polyline", "polygon", "path"]

    // Keys a shape of this type reads besides its type key.
    static func extraKeys(for type: String) -> Set<String> {
        type == "rect" ? ["radius"] : []
    }

    init(type: String, container: KeyedDecodingContainer<AnyKey>) throws {
        let value = try container.superDecoder(forKey: AnyKey(type))
        switch type {
        case "rect":
            let rect = try Rect(from: value)
            guard rect.size.width >= 0, rect.size.height >= 0 else {
                throw value.corrupted("a rect's width and height cannot be negative")
            }
            var cornerRadius: Size?
            if container.contains(AnyKey("radius")) {
                let radius = try container.superDecoder(forKey: AnyKey("radius"))
                let numbers = try radius.numberOrNumbers(count: 2)
                guard numbers.allSatisfy({ $0 >= 0 }) else {
                    throw radius.corrupted("a radius cannot be negative")
                }
                cornerRadius = Size(width: numbers[0], height: numbers.count == 2 ? numbers[1] : numbers[0])
            }
            self = .rect(rect, cornerRadius: cornerRadius)
        case "circle":
            let numbers = try value.numbers(count: 3)
            guard numbers[2] >= 0 else {
                throw value.corrupted("a radius cannot be negative")
            }
            self = .circle(center: Point(x: numbers[0], y: numbers[1]), radius: numbers[2])
        case "ellipse":
            let numbers = try value.numbers(count: 4)
            guard numbers[2] >= 0, numbers[3] >= 0 else {
                throw value.corrupted("a radius cannot be negative")
            }
            self = .ellipse(center: Point(x: numbers[0], y: numbers[1]), radii: Size(width: numbers[2], height: numbers[3]))
        case "line":
            let numbers = try value.numbers(count: 4)
            self = .line(from: Point(x: numbers[0], y: numbers[1]), to: Point(x: numbers[2], y: numbers[3]))
        case "polyline":
            self = .polyline(try [Point](from: value))
        case "polygon":
            self = .polygon(try [Point](from: value))
        default:
            self = .path(try PathData(from: value))
        }
    }

    func encode(into container: inout KeyedEncodingContainer<AnyKey>) throws {
        switch self {
        case .rect(let rect, let cornerRadius):
            try container.encode(rect, "rect")
            if let cornerRadius {
                if cornerRadius.width == cornerRadius.height {
                    try container.encode(cornerRadius.width, "radius")
                } else {
                    try container.encode(cornerRadius, "radius")
                }
            }
        case .circle(let center, let radius):
            try container.encode([center.x, center.y, radius], "circle")
        case .ellipse(let center, let radii):
            try container.encode([center.x, center.y, radii.width, radii.height], "ellipse")
        case .line(let from, let to):
            try container.encode([from.x, from.y, to.x, to.y], "line")
        case .polyline(let points):
            try container.encode(points, "polyline")
        case .polygon(let points):
            try container.encode(points, "polygon")
        case .path(let path):
            try container.encode(path, "path")
        }
    }
}
