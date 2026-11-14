public struct Point: Sendable, Equatable, Codable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = Point(x: 0, y: 0)

    public init(from decoder: any Decoder) throws {
        let numbers = try decoder.numbers(count: 2)
        self.init(x: numbers[0], y: numbers[1])
    }

    public func encode(to encoder: any Encoder) throws {
        try [x, y].encode(to: encoder)
    }
}
