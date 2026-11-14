// A named entry in a document's defs: a paint for "$name", or an element for "use".
public enum Definition: Sendable, Equatable, Codable {
    case paint(Paint)
    case element(Element)

    public init(from decoder: any Decoder) throws {
        if (try? decoder.singleValueContainer().decode(String.self)) != nil {
            let paint = try Paint(from: decoder)
            if case .reference = paint {
                throw decoder.corrupted("a definition cannot be a reference")
            }
            self = .paint(paint)
            return
        }
        let container = try decoder.container(keyedBy: AnyKey.self)
        if container.keyNames.isDisjoint(with: Paint.typeKeys) {
            self = .element(try Element(from: decoder))
        } else {
            self = .paint(try Paint(from: decoder))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .paint(let paint):
            try paint.encode(to: encoder)
        case .element(let element):
            try element.encode(to: encoder)
        }
    }
}
