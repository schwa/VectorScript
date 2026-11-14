// A tile of elements that repeats across the painted area. The tile covers [0, 0, width, height] in the
// painted element's user space, moved by `transform`; content outside the tile is clipped.
public struct Pattern: Sendable, Equatable, Codable {
    public var size: Size
    public var transform: Transform?
    public var elements: [Element]

    public init(size: Size, transform: Transform? = nil, elements: [Element]) {
        self.size = size
        self.transform = transform
        self.elements = elements
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: AnyKey.self)
        try container.rejectUnknownKeys(allowed: ["size", "transform", "elements"])
        size = try container.decode(Size.self, "size")
        transform = try container.decodeIfPresent(Transform.self, "transform")
        elements = try container.decode([Element].self, "elements")
        guard size.width > 0, size.height > 0 else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: container.codingPath + [AnyKey("size")], debugDescription: "a pattern's size must be positive"))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: AnyKey.self)
        try container.encode(size, "size")
        try container.encodeIfPresent(transform, "transform")
        try container.encode(elements, "elements")
    }
}
