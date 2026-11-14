public enum TextAnchor: String, Sendable, Equatable, Codable {
    case start, middle, end
}

// One line of text. The font and font size come from the element's style.
public struct Text: Sendable, Equatable {
    public var string: String
    // The baseline point that `anchor` places the line against.
    public var at: Point
    public var anchor: TextAnchor

    public init(string: String, at: Point, anchor: TextAnchor = .start) {
        self.string = string
        self.at = at
        self.anchor = anchor
    }
}
