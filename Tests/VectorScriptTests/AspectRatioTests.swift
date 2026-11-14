import Testing
@testable import VectorScript

struct AspectRatioTests {
    let viewBox = Rect(x: 0, y: 0, width: 10, height: 10)
    let wide = Rect(x: 0, y: 0, width: 200, height: 100)

    @Test(arguments: [
        ("none", AspectRatio.none),
        ("xMidYMid", AspectRatio.uniform(x: .mid, y: .mid, scaling: .meet)),
        ("xMinYMax slice", AspectRatio.uniform(x: .min, y: .max, scaling: .slice)),
        ("xMaxYMin meet", AspectRatio.uniform(x: .max, y: .min, scaling: .meet)),
    ])
    func `parses svg syntax`(text: String, expected: AspectRatio) throws {
        #expect(try AspectRatio(parsing: text) == expected)
    }

    @Test(arguments: ["", "xMidYmid", "xMidYMid fill", "none slice", "xMidYMid meet extra", "yMidXMid"])
    func `rejects bad values`(text: String) {
        #expect(throws: AspectRatio.ParseError.self) {
            try AspectRatio(parsing: text)
        }
    }

    @Test
    func `round trips as text`() throws {
        for text in ["none", "xMinYMid meet", "xMaxYMax slice"] {
            #expect(try AspectRatio(parsing: text).string == text)
        }
    }

    @Test
    func `none stretches each axis`() {
        let matrix = AspectRatio.none.matrix(mapping: viewBox, onto: wide)
        #expect(matrix == Matrix(a: 20, b: 0, c: 0, d: 10, tx: 0, ty: 0))
    }

    @Test
    func `meet fits and aligns`() {
        let middle = AspectRatio.uniform(x: .mid, y: .mid, scaling: .meet).matrix(mapping: viewBox, onto: wide)
        #expect(middle == Matrix(a: 10, b: 0, c: 0, d: 10, tx: 50, ty: 0))
        let right = AspectRatio.uniform(x: .max, y: .mid, scaling: .meet).matrix(mapping: viewBox, onto: wide)
        #expect(right.tx == 100)
    }

    @Test
    func `slice fills and aligns`() {
        let top = AspectRatio.uniform(x: .mid, y: .min, scaling: .slice).matrix(mapping: viewBox, onto: wide)
        #expect(top == Matrix(a: 20, b: 0, c: 0, d: 20, tx: 0, ty: 0))
        let bottom = AspectRatio.uniform(x: .mid, y: .max, scaling: .slice).matrix(mapping: viewBox, onto: wide)
        #expect(bottom.ty == -100)
    }

    @Test
    func `view box origin is honored`() {
        let matrix = AspectRatio.uniform(x: .min, y: .min, scaling: .meet).matrix(mapping: Rect(x: 5, y: 5, width: 10, height: 10), onto: wide)
        #expect(matrix.applying(to: Point(x: 5, y: 5)) == Point(x: 0, y: 0))
    }

    @Test
    func `documents decode, default and reject`() throws {
        #expect(try document("{ size: [1, 1], elements: [] }").preserveAspectRatio == .none)
        let decoded = try document("{ size: [20, 10], viewBox: [0, 0, 1, 1], preserveAspectRatio: 'xMidYMid slice', elements: [] }")
        #expect(decoded.preserveAspectRatio == .uniform(x: .mid, y: .mid, scaling: .slice))
        #expect(try Document(json: decoded.jsonData()) == decoded)
        #expect(failure("{ size: [1, 1], preserveAspectRatio: 'middle', elements: [] }").hasPrefix("preserveAspectRatio: bad preserveAspectRatio 'middle'"))
    }
}
