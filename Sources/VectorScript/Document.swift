import Foundation

public struct Document: Sendable, Equatable, Codable {
    public static let currentVersion = 1

    public var version: Int
    // The output size in points.
    public var size: Size
    // The user-space rectangle that maps onto `size`; [0, 0, width, height] when nil.
    public var viewBox: Rect?
    public var preserveAspectRatio: AspectRatio
    public var background: Color?
    public var defs: [String: Definition]
    public var elements: [Element]
    // Where the document was read from; relative image paths resolve against it. Not part of the JSON.
    public var baseURL: URL?

    public init(size: Size, viewBox: Rect? = nil, preserveAspectRatio: AspectRatio = .none, background: Color? = nil, defs: [String: Definition] = [:], elements: [Element] = []) {
        version = Self.currentVersion
        self.size = size
        self.viewBox = viewBox
        self.preserveAspectRatio = preserveAspectRatio
        self.background = background
        self.defs = defs
        self.elements = elements
    }

    // Reads JSON5 (so plain JSON too). Errors are `DocumentError`.
    public init(json: Data, baseURL: URL? = nil) throws {
        let decoder = JSONDecoder()
        decoder.allowsJSON5 = true
        do {
            self = try decoder.decode(Document.self, from: json)
        } catch let error as DecodingError {
            throw DocumentError(error)
        }
        self.baseURL = baseURL
    }

    public init(contentsOf url: URL) throws {
        try self.init(json: try Data(contentsOf: url), baseURL: url)
    }

    public func jsonData(prettyPrinted: Bool = true) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = prettyPrinted ? [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes] : [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: AnyKey.self)
        try container.rejectUnknownKeys(allowed: ["$schema", "version", "size", "viewBox", "preserveAspectRatio", "background", "defs", "elements"])
        version = try container.decodeIfPresent(Int.self, "version") ?? Self.currentVersion
        guard version == Self.currentVersion else {
            throw DocumentError.unsupportedVersion(version)
        }
        size = try container.decode(Size.self, "size")
        viewBox = try container.decodeIfPresent(Rect.self, "viewBox")
        preserveAspectRatio = try container.decodeIfPresent(AspectRatio.self, "preserveAspectRatio") ?? .none
        background = try container.decodeIfPresent(Color.self, "background")
        defs = try container.decodeIfPresent([String: Definition].self, "defs") ?? [:]
        elements = try container.decode([Element].self, "elements")
        guard size.width > 0, size.height > 0 else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [AnyKey("size")], debugDescription: "size must be positive"))
        }
        if let viewBox, viewBox.size.width <= 0 || viewBox.size.height <= 0 {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [AnyKey("viewBox")], debugDescription: "viewBox width and height must be positive"))
        }
        try validateReferences()
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: AnyKey.self)
        try container.encode(version, "version")
        try container.encode(size, "size")
        try container.encodeIfPresent(viewBox, "viewBox")
        if preserveAspectRatio != .none {
            try container.encode(preserveAspectRatio, "preserveAspectRatio")
        }
        try container.encodeIfPresent(background, "background")
        if !defs.isEmpty {
            try container.encode(defs, "defs")
        }
        try container.encode(elements, "elements")
    }
}
