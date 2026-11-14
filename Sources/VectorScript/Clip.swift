// A clip region, in the user space of the element it is on (after that element's transform).
public struct Clip: Sendable, Equatable, Codable {
    public var shape: Shape
    public var fillRule: FillRule

    public init(_ shape: Shape, fillRule: FillRule = .nonzero) {
        self.shape = shape
        self.fillRule = fillRule
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: AnyKey.self)
        let type = try container.singleKey(from: Shape.typeKeys, what: "a clip")
        try container.rejectUnknownKeys(allowed: Shape.extraKeys(for: type).union([type, "fillRule"]))
        shape = try Shape(type: type, container: container)
        fillRule = try container.decodeIfPresent(FillRule.self, "fillRule") ?? .nonzero
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: AnyKey.self)
        try shape.encode(into: &container)
        if fillRule != .nonzero {
            try container.encode(fillRule, "fillRule")
        }
    }
}
