import Testing
@testable import VectorScript

struct ColorTests {
    @Test(arguments: [
        ("#f00", Color(red: 1, green: 0, blue: 0)),
        ("#f008", Color(red: 1, green: 0, blue: 0, alpha: 136.0 / 255)),
        ("#00ff00", Color(red: 0, green: 1, blue: 0)),
        ("#0000ff80", Color(red: 0, green: 0, blue: 1, alpha: 128.0 / 255)),
        ("red", Color(red: 1, green: 0, blue: 0)),
        ("CornflowerBlue", Color(red: 100.0 / 255, green: 149.0 / 255, blue: 237.0 / 255)),
        ("transparent", Color.transparent),
    ])
    func `parses colors`(text: String, expected: Color) throws {
        #expect(try Color(parsing: text) == expected)
    }

    @Test(arguments: ["redd", "#12", "#12345", "#ggg", "", "#"])
    func `rejects bad colors`(text: String) {
        #expect(throws: Color.ParseError.unknownColor(text)) {
            try Color(parsing: text)
        }
    }

    @Test
    func `hex string round trips`() throws {
        #expect(try Color(parsing: "#12ab34").hexString == "#12ab34")
        #expect(try Color(parsing: "#12ab3480").hexString == "#12ab3480")
    }

    @Test
    func `a bad color names its place`() {
        #expect(elementFailure("{ circle: [1, 2, 3], fill: 'redd' }") == "elements[0].fill: unknown color 'redd'")
    }
}
