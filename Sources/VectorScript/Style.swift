public enum StrokeCap: String, Sendable, Equatable, Codable {
    case butt, round, square
}

public enum StrokeJoin: String, Sendable, Equatable, Codable {
    case miter, round, bevel
}

public enum FillRule: String, Sendable, Equatable, Codable {
    case nonzero, evenodd
}

// Properties that inherit from groups. nil means "inherit".
public struct Style: Sendable, Equatable, Codable {
    public var fill: Paint?
    public var stroke: Paint?
    public var strokeWidth: Double?
    public var strokeCap: StrokeCap?
    public var strokeJoin: StrokeJoin?
    public var strokeMiterLimit: Double?
    public var strokeDash: [Double]?
    public var strokeDashOffset: Double?
    public var fillRule: FillRule?
    public var font: String?
    public var fontSize: Double?
    // Extra points between characters; negative tightens.
    public var letterSpacing: Double?
    // A font file (see FileReference). When set, `font` only picks a face inside it.
    public var fontFile: String?
    // Distance between baselines, as a multiple of fontSize.
    public var lineHeight: Double?
    public var markerStart: Marker?
    public var markerMid: Marker?
    public var markerEnd: Marker?

    public init(fill: Paint? = nil, stroke: Paint? = nil, strokeWidth: Double? = nil, strokeCap: StrokeCap? = nil, strokeJoin: StrokeJoin? = nil, strokeMiterLimit: Double? = nil, strokeDash: [Double]? = nil, strokeDashOffset: Double? = nil, fillRule: FillRule? = nil, font: String? = nil, fontSize: Double? = nil, letterSpacing: Double? = nil, fontFile: String? = nil, lineHeight: Double? = nil, markerStart: Marker? = nil, markerMid: Marker? = nil, markerEnd: Marker? = nil) {
        self.fill = fill
        self.stroke = stroke
        self.strokeWidth = strokeWidth
        self.strokeCap = strokeCap
        self.strokeJoin = strokeJoin
        self.strokeMiterLimit = strokeMiterLimit
        self.strokeDash = strokeDash
        self.strokeDashOffset = strokeDashOffset
        self.fillRule = fillRule
        self.font = font
        self.fontSize = fontSize
        self.letterSpacing = letterSpacing
        self.fontFile = fontFile
        self.lineHeight = lineHeight
        self.markerStart = markerStart
        self.markerMid = markerMid
        self.markerEnd = markerEnd
    }

    // What the document root starts from.
    public static let initial = Style(fill: .color(.black), stroke: Paint.none, strokeWidth: 1, strokeCap: .butt, strokeJoin: .miter, strokeMiterLimit: 4, strokeDash: [], strokeDashOffset: 0, fillRule: .nonzero, font: "Helvetica", fontSize: 16, letterSpacing: 0, lineHeight: 1.2)

    static let keys: Set<String> = ["fill", "stroke", "strokeWidth", "strokeCap", "strokeJoin", "strokeMiterLimit", "strokeDash", "strokeDashOffset", "fillRule", "font", "fontSize", "letterSpacing", "fontFile", "lineHeight", "markerStart", "markerMid", "markerEnd"]

    public var isEmpty: Bool {
        self == Style()
    }

    // This style, with `other` filling in what it leaves unset.
    public func merged(over other: Style) -> Style {
        Style(
            fill: fill ?? other.fill,
            stroke: stroke ?? other.stroke,
            strokeWidth: strokeWidth ?? other.strokeWidth,
            strokeCap: strokeCap ?? other.strokeCap,
            strokeJoin: strokeJoin ?? other.strokeJoin,
            strokeMiterLimit: strokeMiterLimit ?? other.strokeMiterLimit,
            strokeDash: strokeDash ?? other.strokeDash,
            strokeDashOffset: strokeDashOffset ?? other.strokeDashOffset,
            fillRule: fillRule ?? other.fillRule,
            font: font ?? other.font,
            fontSize: fontSize ?? other.fontSize,
            letterSpacing: letterSpacing ?? other.letterSpacing,
            fontFile: fontFile ?? other.fontFile,
            lineHeight: lineHeight ?? other.lineHeight,
            markerStart: markerStart ?? other.markerStart,
            markerMid: markerMid ?? other.markerMid,
            markerEnd: markerEnd ?? other.markerEnd
        )
    }

    // Reads the style keys of an element; other keys are left for the element.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: AnyKey.self)
        fill = try container.decodeIfPresent(Paint.self, "fill")
        stroke = try container.decodeIfPresent(Paint.self, "stroke")
        strokeWidth = try container.decodeNumberIfPresent("strokeWidth")
        strokeCap = try container.decodeIfPresent(StrokeCap.self, "strokeCap")
        strokeJoin = try container.decodeIfPresent(StrokeJoin.self, "strokeJoin")
        strokeMiterLimit = try container.decodeNumberIfPresent("strokeMiterLimit")
        strokeDash = try container.decodeIfPresent([Number].self, "strokeDash")?.map(\.value)
        strokeDashOffset = try container.decodeNumberIfPresent("strokeDashOffset")
        fillRule = try container.decodeIfPresent(FillRule.self, "fillRule")
        font = try container.decodeIfPresent(String.self, "font")
        fontSize = try container.decodeNumberIfPresent("fontSize")
        letterSpacing = try container.decodeNumberIfPresent("letterSpacing")
        fontFile = try container.decodeIfPresent(String.self, "fontFile")
        lineHeight = try container.decodeNumberIfPresent("lineHeight")
        markerStart = try container.decodeIfPresent(Marker.self, "markerStart")
        markerMid = try container.decodeIfPresent(Marker.self, "markerMid")
        markerEnd = try container.decodeIfPresent(Marker.self, "markerEnd")
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: AnyKey.self)
        try container.encodeIfPresent(fill, "fill")
        try container.encodeIfPresent(stroke, "stroke")
        try container.encodeIfPresent(strokeWidth, "strokeWidth")
        try container.encodeIfPresent(strokeCap, "strokeCap")
        try container.encodeIfPresent(strokeJoin, "strokeJoin")
        try container.encodeIfPresent(strokeMiterLimit, "strokeMiterLimit")
        try container.encodeIfPresent(strokeDash, "strokeDash")
        try container.encodeIfPresent(strokeDashOffset, "strokeDashOffset")
        try container.encodeIfPresent(fillRule, "fillRule")
        try container.encodeIfPresent(font, "font")
        try container.encodeIfPresent(fontSize, "fontSize")
        try container.encodeIfPresent(letterSpacing, "letterSpacing")
        try container.encodeIfPresent(fontFile, "fontFile")
        try container.encodeIfPresent(lineHeight, "lineHeight")
        try container.encodeIfPresent(markerStart, "markerStart")
        try container.encodeIfPresent(markerMid, "markerMid")
        try container.encodeIfPresent(markerEnd, "markerEnd")
    }
}
