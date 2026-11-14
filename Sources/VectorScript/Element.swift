public struct Element: Sendable, Equatable, Codable {
    public enum Content: Sendable, Equatable {
        case shape(Shape)
        case group([Element])
        case use(Use)
        case text(Text)
        case image(RasterImage)
    }

    public var content: Content
    public var style: Style
    // Applies to the element as a whole; not inherited.
    public var opacity: Double?
    public var transform: Transform?
    public var clip: Clip?
    public var mask: Mask?
    // Applies to the element as a whole; not inherited.
    public var blendMode: BlendMode?
    // Applied to the element as a whole, before clip, mask, opacity and blend mode; not inherited.
    public var filter: FilterList?

    public init(_ content: Content, style: Style = Style(), opacity: Double? = nil, transform: Transform? = nil, clip: Clip? = nil, mask: Mask? = nil, blendMode: BlendMode? = nil, filter: FilterList? = nil) {
        self.content = content
        self.style = style
        self.opacity = opacity
        self.transform = transform
        self.clip = clip
        self.mask = mask
        self.blendMode = blendMode
        self.filter = filter
    }

    static let typeKeys: Set<String> = Shape.typeKeys.union(["group", "use", "text", "image"])
    static let commonKeys: Set<String> = Style.keys.union(["opacity", "transform", "clip", "mask", "blendMode", "filter"])

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: AnyKey.self)
        let type = try container.singleKey(from: Self.typeKeys, what: "an element")
        var allowed = Self.commonKeys.union([type])
        switch type {
        case "group":
            content = .group(try container.decode([Element].self, type))
        case "use":
            allowed.insert("at")
            content = .use(Use(name: try container.decode(String.self, type), at: try container.decodeIfPresent(Point.self, "at")))
        case "text":
            allowed.formUnion(["at", "anchor", "width"])
            let width = try container.decodeIfPresent(Double.self, "width")
            if let width, width <= 0 {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: container.codingPath + [AnyKey("width")], debugDescription: "a text width must be positive"))
            }
            content = .text(Text(string: try container.decode(String.self, type), at: try container.decode(Point.self, "at"), anchor: try container.decodeIfPresent(TextAnchor.self, "anchor") ?? .start, width: width))
        case "image":
            // Images have no fill or stroke, so style keys would do nothing.
            allowed = [type, "at", "size", "opacity", "transform", "clip", "mask", "blendMode", "filter"]
            let image = RasterImage(source: try container.decode(String.self, type), at: try container.decodeIfPresent(Point.self, "at") ?? .zero, size: try container.decodeIfPresent(Size.self, "size"))
            if let size = image.size, size.width <= 0 || size.height <= 0 {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: container.codingPath + [AnyKey("size")], debugDescription: "an image's size must be positive"))
            }
            content = .image(image)
        default:
            allowed.formUnion(Shape.extraKeys(for: type))
            content = .shape(try Shape(type: type, container: container))
        }
        try container.rejectUnknownKeys(allowed: allowed)
        style = try Style(from: decoder)
        opacity = try container.decodeIfPresent(Double.self, "opacity")
        transform = try container.decodeIfPresent(Transform.self, "transform")
        clip = try container.decodeIfPresent(Clip.self, "clip")
        mask = try container.decodeIfPresent(Mask.self, "mask")
        blendMode = try container.decodeIfPresent(BlendMode.self, "blendMode")
        filter = try container.decodeIfPresent(FilterList.self, "filter")
        if let opacity, !(0...1).contains(opacity) {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: container.codingPath + [AnyKey("opacity")], debugDescription: "opacity \(formatNumber(opacity)) is outside 0...1"))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: AnyKey.self)
        switch content {
        case .shape(let shape):
            try shape.encode(into: &container)
        case .group(let elements):
            try container.encode(elements, "group")
        case .use(let use):
            try container.encode(use.name, "use")
            try container.encodeIfPresent(use.at, "at")
        case .text(let text):
            try container.encode(text.string, "text")
            try container.encode(text.at, "at")
            if text.anchor != .start {
                try container.encode(text.anchor, "anchor")
            }
            try container.encodeIfPresent(text.width, "width")
        case .image(let image):
            try container.encode(image.source, "image")
            if image.at != .zero {
                try container.encode(image.at, "at")
            }
            try container.encodeIfPresent(image.size, "size")
        }
        try style.encode(to: encoder)
        try container.encodeIfPresent(opacity, "opacity")
        try container.encodeIfPresent(transform, "transform")
        try container.encodeIfPresent(clip, "clip")
        try container.encodeIfPresent(mask, "mask")
        try container.encodeIfPresent(blendMode, "blendMode")
        try container.encodeIfPresent(filter, "filter")
    }
}
