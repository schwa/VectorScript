import Foundation

// A file named in a document: a path relative to the document's file, an absolute path, or a file: URL.
public enum FileReference {
    public enum Error: Swift.Error, Equatable, CustomStringConvertible {
        case relativePathWithoutBase(String)

        public var description: String {
            switch self {
            case .relativePathWithoutBase(let path): "'\(path)' is relative, but the document has no file URL"
            }
        }
    }

    public static func url(for path: String, relativeTo baseURL: URL?) throws(Error) -> URL {
        if path.hasPrefix("file:"), let url = URL(string: path) {
            return url
        }
        if path.hasPrefix("/") {
            return URL(filePath: path)
        }
        guard let baseURL else {
            throw .relativePathWithoutBase(path)
        }
        return URL(filePath: path, relativeTo: baseURL.deletingLastPathComponent()).standardizedFileURL
    }
}
