// One step of an element's filter list. The meanings are CSS filter functions'. Lengths are user units.
public enum Filter: Sendable, Equatable, Codable {
    // Gaussian blur; the radius is the standard deviation.
    case blur(Double)
    case dropShadow(offset: Point, blur: Double, color: Color)
    // 0 leaves colors alone, 1 is fully gray. Same for sepia and invert.
    case grayscale(Double)
    case sepia(Double)
    case invert(Double)
    // 1 leaves colors alone; 0 is gray, 2 doubles saturation.
    case saturate(Double)
    // 1 leaves colors alone; 0 is black.
    case brightness(Double)
    // 1 leaves colors alone; 0 is mid gray.
    case contrast(Double)
    // Degrees around the color wheel.
    case hueRotate(Double)

    static let typeKeys: Set<String> = ["blur", "dropShadow", "grayscale", "sepia", "invert", "saturate", "brightness", "contrast", "hueRotate"]

    // How far, in user units, the filter can spread content past its edges.
    public var reach: Double {
        switch self {
        case .blur(let radius):
            radius * 3
        case .dropShadow(let offset, let blur, _):
            max(abs(offset.x), abs(offset.y)) + blur * 3
        default:
            0
        }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: AnyKey.self)
        let type = try container.singleKey(from: Self.typeKeys, what: "a filter")
        try container.rejectUnknownKeys(allowed: [type])
        if type == "dropShadow" {
            let shadow = try container.nestedContainer(keyedBy: AnyKey.self, forKey: AnyKey(type))
            try shadow.rejectUnknownKeys(allowed: ["offset", "blur", "color"])
            let blur = try shadow.decodeNumberIfPresent("blur") ?? 0
            guard blur >= 0 else {
                throw shadow.corrupted("a shadow's blur cannot be negative")
            }
            self = .dropShadow(offset: try shadow.decodeIfPresent(Point.self, "offset") ?? .zero, blur: blur, color: try shadow.decodeIfPresent(Color.self, "color") ?? Color(red: 0, green: 0, blue: 0, alpha: 0.5))
            return
        }
        let value = try container.decodeNumber(type)
        let valueDecoder = try container.superDecoder(forKey: AnyKey(type))
        switch type {
        case "blur":
            guard value >= 0 else {
                throw valueDecoder.corrupted("a blur radius cannot be negative")
            }
            self = .blur(value)
        case "grayscale", "sepia", "invert":
            guard (0...1).contains(value) else {
                throw valueDecoder.corrupted("\(type) takes 0...1")
            }
            self = type == "grayscale" ? .grayscale(value) : (type == "sepia" ? .sepia(value) : .invert(value))
        case "saturate", "brightness", "contrast":
            guard value >= 0 else {
                throw valueDecoder.corrupted("\(type) cannot be negative")
            }
            self = type == "saturate" ? .saturate(value) : (type == "brightness" ? .brightness(value) : .contrast(value))
        default:
            self = .hueRotate(value)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: AnyKey.self)
        switch self {
        case .blur(let radius): try container.encode(radius, "blur")
        case .grayscale(let amount): try container.encode(amount, "grayscale")
        case .sepia(let amount): try container.encode(amount, "sepia")
        case .invert(let amount): try container.encode(amount, "invert")
        case .saturate(let amount): try container.encode(amount, "saturate")
        case .brightness(let amount): try container.encode(amount, "brightness")
        case .contrast(let amount): try container.encode(amount, "contrast")
        case .hueRotate(let degrees): try container.encode(degrees, "hueRotate")
        case .dropShadow(let offset, let blur, let color):
            var shadow = container.nestedContainer(keyedBy: AnyKey.self, forKey: AnyKey("dropShadow"))
            try shadow.encode(offset, "offset")
            try shadow.encode(blur, "blur")
            try shadow.encode(color, "color")
        }
    }
}

// An element's filters, applied in order. JSON: a list of filters, or one filter object.
public struct FilterList: Sendable, Equatable, Codable {
    public var filters: [Filter]

    public init(_ filters: [Filter]) {
        self.filters = filters
    }

    public init(from decoder: any Decoder) throws {
        if (try? decoder.unkeyedContainer()) != nil {
            filters = try [Filter](from: decoder)
        } else {
            filters = [try Filter(from: decoder)]
        }
    }

    public func encode(to encoder: any Encoder) throws {
        try filters.encode(to: encoder)
    }
}
