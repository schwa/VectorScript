import SwiftUI
import Testing
@testable import VectorScriptViewerSupport

struct JSON5HighlighterTests {
    func kinds(_ text: String) -> [(JSON5Highlighter.Kind, String)] {
        let characters = Array(text)
        return JSON5Highlighter.tokens(in: text).map { ($0.kind, String(characters[$0.range])) }
    }

    @Test
    func `classifies every token kind`() {
        let tokens = kinds("{ size: [256, -1.5e3], \"fill\": '$sky', stroke: \"#fc0\", text: \"hi\", on: true } // done")
        let expected: [(JSON5Highlighter.Kind, String)] = [
            (.punctuation, "{"), (.key, "size"), (.punctuation, ":"), (.punctuation, "["), (.number, "256"), (.punctuation, ","),
            (.number, "-1.5e3"), (.punctuation, "]"), (.punctuation, ","), (.key, "\"fill\""), (.punctuation, ":"),
            (.reference, "'$sky'"), (.punctuation, ","), (.key, "stroke"), (.punctuation, ":"), (.color, "\"#fc0\""),
            (.punctuation, ","), (.key, "text"), (.punctuation, ":"), (.string, "\"hi\""), (.punctuation, ","), (.key, "on"),
            (.punctuation, ":"), (.keyword, "true"), (.punctuation, "}"), (.comment, "// done"),
        ]
        #expect(tokens.map(\.0) == expected.map(\.0))
        #expect(tokens.map(\.1) == expected.map(\.1))
    }

    @Test
    func `handles block comments, escapes and unfinished text`() {
        #expect(kinds("/* a\nb */ 1").map(\.0) == [.comment, .number])
        #expect(kinds("\"a\\\"b\"").map(\.1) == ["\"a\\\"b\""])
        #expect(kinds("\"open").map(\.0) == [.string])
        #expect(kinds("/* open").map(\.0) == [.comment])
    }

    @Test
    func `highlighting keeps the characters and colors tokens`() {
        let source = "{ size: [1, 2] } // note"
        let text = JSON5Highlighter.highlighted(source)
        #expect(String(text.characters) == source)
        let colors = text.runs.map(\.foregroundColor)
        #expect(colors.contains(JSON5Highlighter.color(for: .key)))
        #expect(colors.contains(JSON5Highlighter.color(for: .number)))
        #expect(colors.contains(JSON5Highlighter.color(for: .comment)))
    }

    @Test
    func `highlights multi-scalar characters at the right place`() {
        let source = "{ text: \"👋🏽\", n: 1 }"
        let text = JSON5Highlighter.highlighted(source)
        let numberRun = text.runs.first { $0.foregroundColor == JSON5Highlighter.color(for: .number) }
        #expect(numberRun.map { String(text[$0.range].characters) } == "1")
    }
}
