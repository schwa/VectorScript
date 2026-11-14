public enum DocumentError: Error, Equatable, CustomStringConvertible {
    // `path` is the place in the JSON, such as "elements[3].fill". Empty for the document itself.
    case invalid(path: String, message: String)
    case malformedJSON(String)
    case unsupportedVersion(Int)

    public var description: String {
        switch self {
        case .invalid(let path, let message):
            path.isEmpty ? message : "\(path): \(message)"
        case .malformedJSON(let message):
            "malformed JSON: \(message)"
        case .unsupportedVersion(let version):
            "unsupported version \(version) (this reader knows version \(Document.currentVersion))"
        }
    }
}

extension DocumentError {
    init(_ error: DecodingError) {
        switch error {
        case .keyNotFound(let key, let context):
            self = .invalid(path: Self.path(context.codingPath), message: "missing key '\(key.stringValue)'")
        case .typeMismatch(_, let context), .valueNotFound(_, let context):
            self = .invalid(path: Self.path(context.codingPath), message: context.debugDescription)
        case .dataCorrupted(let context):
            if context.codingPath.isEmpty, let underlying = context.underlyingError {
                self = .malformedJSON((underlying as NSError).userInfo[NSDebugDescriptionErrorKey] as? String ?? underlying.localizedDescription)
            } else {
                self = .invalid(path: Self.path(context.codingPath), message: context.debugDescription)
            }
        @unknown default:
            self = .invalid(path: "", message: "\(error)")
        }
    }

    static func path(_ codingPath: [any CodingKey]) -> String {
        var result = ""
        for key in codingPath {
            if let index = key.intValue {
                result += "[\(index)]"
            } else {
                result += result.isEmpty ? key.stringValue : ".\(key.stringValue)"
            }
        }
        return result
    }
}

import Foundation
