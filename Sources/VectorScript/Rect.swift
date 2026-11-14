public struct Rect: Sendable, Equatable, Codable {
    public var origin: Point
    public var size: Size

    public init(origin: Point, size: Size) {
        self.origin = origin
        self.size = size
    }

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.init(origin: Point(x: x, y: y), size: Size(width: width, height: height))
    }

    public init(from decoder: any Decoder) throws {
        let numbers = try decoder.numbers(count: 4)
        self.init(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3])
    }

    public func encode(to encoder: any Encoder) throws {
        try [origin.x, origin.y, size.width, size.height].encode(to: encoder)
    }
}
