public enum MaskMode: String, Sendable, Equatable, Codable {
    // Bright mask content shows the element: white shows it fully, black hides it. Transparent hides it.
    case luminance
    // Only the mask content's opacity counts.
    case alpha
}

// Elements whose brightness or opacity sets how much of the masked element shows. In the masked element's own
// coordinates, after its transform, like a clip.
public struct Mask: Sendable, Equatable, Codable {
    public var mode: MaskMode
    public var elements: [Element]

    public init(mode: MaskMode = .luminance, elements: [Element]) {
        self.mode = mode
        self.elements = elements
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: AnyKey.self)
        try container.rejectUnknownKeys(allowed: ["mode", "elements"])
        mode = try container.decodeIfPresent(MaskMode.self, "mode") ?? .luminance
        elements = try container.decode([Element].self, "elements")
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: AnyKey.self)
        if mode != .luminance {
            try container.encode(mode, "mode")
        }
        try container.encode(elements, "elements")
    }
}
