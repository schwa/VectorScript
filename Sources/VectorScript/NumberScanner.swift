import Foundation

// Reads SVG numbers: sign, digits, one '.', optional exponent. "1-2" and "0.5.5" are two numbers each.
struct NumberScanner {
    private let bytes: [UInt8]
    private(set) var index = 0

    init(_ text: String) {
        bytes = Array(text.utf8)
    }

    var isAtEnd: Bool {
        mutating get {
            skipSeparators()
            return index >= bytes.count
        }
    }

    mutating func skipSeparators() {
        while index < bytes.count, Self.isSeparator(bytes[index]) {
            index += 1
        }
    }

    private static func isSeparator(_ byte: UInt8) -> Bool {
        byte == UInt8(ascii: " ") || byte == UInt8(ascii: ",") || byte == UInt8(ascii: "\t") || byte == UInt8(ascii: "\n") || byte == UInt8(ascii: "\r")
    }

    private static func isDigit(_ byte: UInt8) -> Bool {
        byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9")
    }

    // The next byte, when it is an ASCII letter.
    mutating func letter() -> Character? {
        skipSeparators()
        guard index < bytes.count else {
            return nil
        }
        let byte = bytes[index]
        guard (byte >= UInt8(ascii: "a") && byte <= UInt8(ascii: "z")) || (byte >= UInt8(ascii: "A") && byte <= UInt8(ascii: "Z")) else {
            return nil
        }
        index += 1
        return Character(UnicodeScalar(byte))
    }

    // An arc flag: one '0' or '1', which may run straight into the next number.
    mutating func flag() -> Bool? {
        skipSeparators()
        guard index < bytes.count, bytes[index] == UInt8(ascii: "0") || bytes[index] == UInt8(ascii: "1") else {
            return nil
        }
        index += 1
        return bytes[index - 1] == UInt8(ascii: "1")
    }

    mutating func number() -> Double? {
        skipSeparators()
        let start = index
        var position = index
        if position < bytes.count, bytes[position] == UInt8(ascii: "-") || bytes[position] == UInt8(ascii: "+") {
            position += 1
        }
        var digits = 0
        while position < bytes.count, Self.isDigit(bytes[position]) {
            position += 1
            digits += 1
        }
        if position < bytes.count, bytes[position] == UInt8(ascii: ".") {
            position += 1
            while position < bytes.count, Self.isDigit(bytes[position]) {
                position += 1
                digits += 1
            }
        }
        guard digits > 0 else {
            return nil
        }
        if position < bytes.count, bytes[position] == UInt8(ascii: "e") || bytes[position] == UInt8(ascii: "E") {
            var exponent = position + 1
            if exponent < bytes.count, bytes[exponent] == UInt8(ascii: "-") || bytes[exponent] == UInt8(ascii: "+") {
                exponent += 1
            }
            if exponent < bytes.count, Self.isDigit(bytes[exponent]) {
                while exponent < bytes.count, Self.isDigit(bytes[exponent]) {
                    exponent += 1
                }
                position = exponent
            }
        }
        guard let value = Double(String(decoding: bytes[start..<position], as: UTF8.self)) else {
            return nil
        }
        index = position
        return value
    }
}
