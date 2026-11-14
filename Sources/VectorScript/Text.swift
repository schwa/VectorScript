public enum TextAnchor: String, Sendable, Equatable, Codable {
    case start, middle, end
}

// Text; "\n" starts a new line. The font, size and line height come from the element's style.
public struct Text: Sendable, Equatable {
    public var string: String
    // The first line's baseline point, which `anchor` places each line against.
    public var at: Point
    public var anchor: TextAnchor
    // When set, lines wrap at word breaks to fit this many points.
    public var width: Double?
    // When set, the text runs along this path instead of from `at`: one line, each glyph turned to follow it.
    public var onPath: PathData?
    // Distance along `onPath` that `anchor` places the text against.
    public var offset: Double

    public init(string: String, at: Point = .zero, anchor: TextAnchor = .start, width: Double? = nil, onPath: PathData? = nil, offset: Double = 0) {
        self.string = string
        self.at = at
        self.anchor = anchor
        self.width = width
        self.onPath = onPath
        self.offset = offset
    }
}
