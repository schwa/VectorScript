import Foundation
import Testing
@testable import VectorScript

func document(_ json: String) throws -> Document {
    try Document(json: Data(json.utf8))
}

// A document holding `elements`, a JSON5 array body.
func document(elements: String, defs: String = "{}") throws -> Document {
    try document("{ size: [100, 100], defs: \(defs), elements: [\(elements)] }")
}

func element(_ json: String) throws -> Element {
    try document(elements: json).elements[0]
}

// The error message decoding `json` gives.
func failure(_ json: String) -> String {
    do {
        _ = try document(json)
        return "no error"
    } catch {
        return "\(error)"
    }
}

func elementFailure(_ json: String, defs: String = "{}") -> String {
    failure("{ size: [100, 100], defs: \(defs), elements: [\(json)] }")
}
