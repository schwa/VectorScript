import Foundation
import Testing
@testable import VectorScript

struct ExpressionTests {
    func evaluate(_ text: String, _ values: [String: Double] = [:]) throws -> Double {
        try NumberExpression(parsing: text).evaluate { name throws(NumberExpression.Error) in
            guard let value = values[name] else {
                throw NumberExpression.Error(message: "no parameter named '\(name)'")
            }
            return value
        }
    }

    @Test(arguments: [
        ("1 + 2 * 3", 7.0), ("(1 + 2) * 3", 9), ("-2 * -3", 6), ("7 % 4", 3), ("2 < 3", 1), ("2 >= 3", 0),
        ("1 && 0", 0), ("0 || 2", 1), ("!0", 1), ("1 == 1 && 2 != 3", 1), ("1.5e2", 150),
        ("min(4, 2, 8)", 2), ("max(1, 9)", 9), ("pow(2, 10)", 1024), ("round(2.5)", 3), ("floor(-1.5)", -2),
        ("clamp(12, 0, 10)", 10), ("lerp(0, 10, 0.25)", 2.5), ("degrees(pi)", 180), ("sign(-4)", -1), ("abs(-3) + sqrt(16)", 7),
    ])
    func `evaluates expressions`(text: String, expected: Double) throws {
        #expect(abs(try evaluate(text) - expected) < 1e-9)
    }

    @Test
    func `reads parameters`() throws {
        #expect(try evaluate("$W / 2 + $PAD", ["W": 100, "PAD": 4]) == 54)
        #expect(try evaluate("if($BIG, 10, 5)", ["BIG": 0]) == 5)
    }

    @Test
    func `if evaluates only the branch it takes`() throws {
        #expect(try evaluate("if(1, 2, $MISSING)") == 2)
        #expect(try evaluate("0 && $MISSING") == 0)
    }

    @Test(arguments: ["1 +", "(1", "foo", "foo(1)", "$", "1 / 0", "min()", "pow(1)", "2 $X"])
    func `rejects bad expressions`(text: String) {
        #expect(throws: NumberExpression.Error.self) {
            try evaluate(text, ["X": 1])
        }
    }
}

struct ParameterTests {
    @Test
    func `numbers anywhere can be expressions`() throws {
        let document = try document("""
        { parameters: { W: 200, H: "$W / 2", R: "min($W, $H) / 4" },
          size: ["$W", "$H"],
          elements: [
            { circle: ["$W / 2", "$H / 2", "$R"], strokeWidth: "$R / 5", opacity: "0.5 + 0.25" },
            { rect: [0, 0, "$W", 10], radius: "$R / 2", transform: { rotate: "$R" } },
            { polyline: [[0, 0], ["$W", "$H"]], strokeDash: ["$R", 2] }
          ] }
        """)
        #expect(document.size == Size(width: 200, height: 100))
        #expect(document.elements[0].content == .shape(.circle(center: Point(x: 100, y: 50), radius: 25)))
        #expect(document.elements[0].style.strokeWidth == 5)
        #expect(document.elements[0].opacity == 0.75)
        #expect(document.elements[1].content == .shape(.rect(Rect(x: 0, y: 0, width: 200, height: 10), cornerRadius: Size(width: 12.5, height: 12.5))))
        #expect(document.elements[1].transform?.operations == [.rotate(degrees: 25, center: nil)])
        #expect(document.elements[2].style.strokeDash == [25, 2])
    }

    @Test
    func `braces work inside path data and transform strings`() throws {
        let document = try document("{ parameters: { X: 10, S: 2 }, size: [100, 100], elements: [{ path: 'M {$X} 0 L {$X * 3}{$X}', transform: 'translate({$X} 5) scale({$S})' }] }")
        #expect(document.elements[0].content == .shape(.path(PathData([.move(to: Point(x: 10, y: 0)), .line(to: Point(x: 30, y: 10))]))))
        #expect(document.elements[0].transform?.operations == [.translate(x: 10, y: 5), .scale(x: 2, y: 2)])
    }

    @Test
    func `color parameters are paints`() throws {
        let resolved = try document("{ parameters: { HULL: '#336699' }, size: [10, 10], elements: [{ rect: [0, 0, 1, 1], fill: '$HULL' }] }").resolved()
        #expect(resolved.elements[0].style.fill == .color(try Color(parsing: "#336699")))
    }

    @Test
    func `parameters can be overridden`() throws {
        let json = Data("{ parameters: { W: 10, C: '#000', H: '$W * 2' }, size: ['$W', '$H'], elements: [{ rect: [0, 0, 1, 1], fill: '$C' }] }".utf8)
        let document = try Document(json: json, parameters: ["W": 30, "C": .color(.white)])
        #expect(document.size == Size(width: 30, height: 60))
        #expect(try document.resolved().elements[0].style.fill == .color(.white))
        let expression = try Document(json: json, parameters: ["H": .expression("$W + 1")])
        #expect(expression.size.height == 11)
    }

    @Test
    func `rejects parameter problems`() {
        #expect(failure("{ parameters: { A: '$B', B: '$A + 1' }, size: [1, 1], elements: [] }").contains("parameter cycle"))
        #expect(failure("{ size: ['$W', 1], elements: [] }") == "size[0]: no parameter named 'W'")
        #expect(failure("{ parameters: { C: '#fff' }, size: ['$C', 1], elements: [] }") == "size[0]: $C is a color, not a number")
        #expect(failure("{ parameters: { dot: 1 }, size: [1, 1], defs: { dot: { circle: [0, 0, 1] } }, elements: [] }") == "defs.dot: 'dot' is both a parameter and a definition")
        #expect(failure("{ parameters: { 'bad name': 1 }, size: [1, 1], elements: [] }").contains("a parameter name is letters"))
        #expect(failure("{ parameters: { C: '#ggg' }, size: [1, 1], elements: [] }") == "parameters.C: unknown color '#ggg'")
        #expect(failure("{ size: [1, 1], elements: [{ path: 'M {$X 0' }] }").hasPrefix("elements[0].path: missing '}'"))
        #expect(throws: DocumentError.invalid(path: "parameters", message: "'Q' is set from outside but is not a parameter of the document")) {
            try Document(json: Data("{ size: [1, 1], elements: [] }".utf8), parameters: ["Q": 1])
        }
    }

    @Test
    func `the evaluated document encodes as plain numbers`() throws {
        let document = try document("{ parameters: { W: 8 }, size: ['$W', '$W'], elements: [{ circle: [0, 0, '$W / 2'] }] }")
        let reloaded = try Document(json: document.jsonData())
        #expect(reloaded == document)
    }
}
