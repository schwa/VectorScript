public struct Size: Sendable, Equatable, Codable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    public init(from decoder: any Decoder) throws {
        let numbers = try decoder.numbers(count: 2)
        self.init(width: numbers[0], height: numbers[1])
    }

    public func encode(to encoder: any Encoder) throws {
        try [width, height].encode(to: encoder)
    }
}
