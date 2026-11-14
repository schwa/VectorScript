import Foundation

// A bitmap placed with its top left corner at `at`. `source` is a path relative to the document's file, a file
// URL, or a data: URI.
public struct RasterImage: Sendable, Equatable {
    public var source: String
    public var at: Point
    // The image's pixel size in points when nil.
    public var size: Size?

    public init(source: String, at: Point = .zero, size: Size? = nil) {
        self.source = source
        self.at = at
        self.size = size
    }

    public enum SourceError: Error, Equatable, CustomStringConvertible {
        case badDataURI
        case relativePathWithoutBase(String)

        public var description: String {
            switch self {
            case .badDataURI: "bad data: URI (expected data:<type>;base64,<data>)"
            case .relativePathWithoutBase(let path): "image '\(path)' is relative, but the document has no file URL"
            }
        }
    }

    public enum Location: Sendable, Equatable {
        case file(URL)
        case data(Data)
    }

    public func location(relativeTo baseURL: URL?) throws(SourceError) -> Location {
        if source.hasPrefix("data:") {
            guard let comma = source.firstIndex(of: ","), source[..<comma].hasSuffix(";base64"), let data = Data(base64Encoded: String(source[source.index(after: comma)...]), options: .ignoreUnknownCharacters) else {
                throw .badDataURI
            }
            return .data(data)
        }
        do {
            return .file(try FileReference.url(for: source, relativeTo: baseURL))
        } catch {
            throw .relativePathWithoutBase(source)
        }
    }
}
