// Draws an element from the document's defs.
public struct Use: Sendable, Equatable {
    public var name: String
    // Where the definition's origin goes.
    public var at: Point?

    public init(name: String, at: Point? = nil) {
        self.name = name
        self.at = at
    }
}
