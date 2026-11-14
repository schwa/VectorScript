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

    public init(string: String, at: Point, anchor: TextAnchor = .start, width: Double? = nil) {
        self.string = string
        self.at = at
        self.anchor = anchor
        self.width = width
    }
}
