import SwiftUI

// Splits JSON5 into colored tokens. It never fails: text it cannot classify is left plain.
public enum JSON5Highlighter {
    public enum Kind: Sendable, Equatable {
        case comment
        case key
        case string
        // "$name": a reference into defs.
        case reference
        // "#rrggbb" and friends.
        case color
        case number
        // true, false, null, and words like Infinity and NaN.
        case keyword
        case punctuation
    }

    public struct Token: Sendable, Equatable {
        public var kind: Kind
        // Character offsets into the text.
        public var range: Range<Int>
    }

    public static func tokens(in text: String) -> [Token] {
        tokens(in: Array(text))
    }

    static func tokens(in characters: [Character]) -> [Token] {
        var tokens: [Token] = []
        var index = 0
        let count = characters.count

        func peek(_ offset: Int = 0) -> Character? {
            index + offset < count ? characters[index + offset] : nil
        }

        // The next non-space character after `position`, to tell keys (followed by ':') from values.
        func isFollowedByColon(from position: Int) -> Bool {
            var cursor = position
            while cursor < count, characters[cursor].isWhitespace {
                cursor += 1
            }
            return cursor < count && characters[cursor] == ":"
        }

        while index < count {
            let character = characters[index]
            let start = index
            if character.isWhitespace {
                index += 1
            } else if character == "/", peek(1) == "/" {
                while index < count, characters[index] != "\n" {
                    index += 1
                }
                tokens.append(Token(kind: .comment, range: start..<index))
            } else if character == "/", peek(1) == "*" {
                index += 2
                while index < count, !(characters[index] == "*" && peek(1) == "/") {
                    index += 1
                }
                index = min(count, index + 2)
                tokens.append(Token(kind: .comment, range: start..<index))
            } else if character == "\"" || character == "'" {
                index += 1
                while index < count, characters[index] != character, characters[index] != "\n" {
                    index += characters[index] == "\\" ? 2 : 1
                }
                index = min(count, index + 1)
                let body = characters[min(start + 1, count)..<max(start + 1, index - 1)]
                let kind: Kind
                if isFollowedByColon(from: index) {
                    kind = .key
                } else if body.first == "$" {
                    kind = .reference
                } else if body.first == "#" {
                    kind = .color
                } else {
                    kind = .string
                }
                tokens.append(Token(kind: kind, range: start..<index))
            } else if character.isNumber || ((character == "-" || character == "+" || character == ".") && (peek(1)?.isNumber ?? false)) {
                index += 1
                while index < count, characters[index].isNumber || characters[index].isLetter || characters[index] == "." || ((characters[index] == "-" || characters[index] == "+") && (characters[index - 1] == "e" || characters[index - 1] == "E")) {
                    index += 1
                }
                tokens.append(Token(kind: .number, range: start..<index))
            } else if character.isLetter || character == "_" || character == "$" {
                while index < count, characters[index].isLetter || characters[index].isNumber || characters[index] == "_" || characters[index] == "$" {
                    index += 1
                }
                let kind: Kind = isFollowedByColon(from: index) ? .key : .keyword
                tokens.append(Token(kind: kind, range: start..<index))
            } else if "{}[]:,".contains(character) {
                index += 1
                tokens.append(Token(kind: .punctuation, range: start..<index))
            } else {
                index += 1
            }
        }
        return tokens
    }

    public static func color(for kind: Kind) -> Color {
        switch kind {
        case .comment: .secondary
        case .key: .blue
        case .string: .red
        case .reference: .purple
        case .color: .pink
        case .number: .orange
        case .keyword: .teal
        case .punctuation: .secondary
        }
    }

    // Colors `text` in place. Only attributes change, so the selection survives.
    public static func highlight(_ text: inout AttributedString) {
        let characters = Array(text.characters)
        var indices = Array(text.characters.indices)
        indices.append(text.endIndex)
        text.foregroundColor = nil
        for token in tokens(in: characters) where token.range.upperBound <= characters.count {
            text[indices[token.range.lowerBound]..<indices[token.range.upperBound]].foregroundColor = color(for: token.kind)
        }
    }

    public static func highlighted(_ source: String) -> AttributedString {
        var text = AttributedString(source)
        highlight(&text)
        return text
    }
}
