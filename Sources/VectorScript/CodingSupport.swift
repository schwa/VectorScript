struct AnyKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init(_ name: String) {
        self.init(stringValue: name)
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}

extension Decoder {
    func corrupted(_ message: String) -> DecodingError {
        DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPath, debugDescription: message))
    }

    func numbers(count: Int) throws -> [Double] {
        let numbers = try [Number](from: self).map(\.value)
        guard numbers.count == count else {
            throw corrupted("expected \(count) numbers, found \(numbers.count)")
        }
        return numbers
    }

    // A value that is one number or a list of `count` numbers.
    func numberOrNumbers(count: Int) throws -> [Double] {
        if (try? unkeyedContainer()) == nil {
            return [try Number(from: self).value]
        }
        return try numbers(count: count)
    }
}

extension KeyedDecodingContainer where K == AnyKey {
    var keyNames: Set<String> {
        Set(allKeys.map(\.stringValue))
    }

    func corrupted(_ message: String) -> DecodingError {
        DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPath, debugDescription: message))
    }

    func rejectUnknownKeys(allowed: Set<String>) throws {
        let unknown = keyNames.subtracting(allowed).sorted()
        if let first = unknown.first {
            throw corrupted("unknown key '\(first)'")
        }
    }

    // The one key present from `candidates`.
    func singleKey(from candidates: Set<String>, what: String) throws -> String {
        let found = keyNames.intersection(candidates).sorted()
        guard let first = found.first else {
            throw corrupted("\(what) needs one of: \(candidates.sorted().joined(separator: ", "))")
        }
        guard found.count == 1 else {
            throw corrupted("\(what) has more than one type key: \(found.joined(separator: ", "))")
        }
        return first
    }

    func decode<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
        try decode(type, forKey: AnyKey(name))
    }

    func decodeIfPresent<T: Decodable>(_ type: T.Type, _ name: String) throws -> T? {
        try decodeIfPresent(type, forKey: AnyKey(name))
    }
}

extension KeyedEncodingContainer where K == AnyKey {
    mutating func encode<T: Encodable>(_ value: T, _ name: String) throws {
        try encode(value, forKey: AnyKey(name))
    }

    mutating func encodeIfPresent<T: Encodable>(_ value: T?, _ name: String) throws {
        try encodeIfPresent(value, forKey: AnyKey(name))
    }
}

func formatNumber(_ value: Double) -> String {
    if value == value.rounded(), abs(value) < 1e15 {
        return String(Int(value))
    }
    return "\(value)"
}
