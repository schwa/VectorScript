public enum Paint: Sendable, Equatable, Codable {
    case none
    case color(Color)
    case linearGradient(LinearGradient)
    case radialGradient(RadialGradient)
    // "$name": a paint in the document's defs.
    case reference(String)

    static let typeKeys: Set<String> = ["linearGradient", "radialGradient"]

    public init(from decoder: any Decoder) throws {
        if let text = try? decoder.singleValueContainer().decode(String.self) {
            if text == "none" {
                self = .none
            } else if text.hasPrefix("$") {
                self = .reference(String(text.dropFirst()))
            } else {
                self = .color(try Color(from: decoder))
            }
            return
        }
        let container = try decoder.container(keyedBy: AnyKey.self)
        let type = try container.singleKey(from: Self.typeKeys, what: "a paint")
        try container.rejectUnknownKeys(allowed: [type])
        if type == "linearGradient" {
            self = .linearGradient(try container.decode(LinearGradient.self, type))
        } else {
            self = .radialGradient(try container.decode(RadialGradient.self, type))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .none:
            var container = encoder.singleValueContainer()
            try container.encode("none")
        case .color(let color):
            try color.encode(to: encoder)
        case .reference(let name):
            var container = encoder.singleValueContainer()
            try container.encode("$" + name)
        case .linearGradient(let gradient):
            var container = encoder.container(keyedBy: AnyKey.self)
            try container.encode(gradient, "linearGradient")
        case .radialGradient(let gradient):
            var container = encoder.container(keyedBy: AnyKey.self)
            try container.encode(gradient, "radialGradient")
        }
    }
}
