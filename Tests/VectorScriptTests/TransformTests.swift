import Testing
@testable import VectorScript

struct TransformTests {
    func close(_ a: Point, _ b: Point) -> Bool {
        abs(a.x - b.x) < 1e-9 && abs(a.y - b.y) < 1e-9
    }

    @Test
    func `parses the svg syntax`() throws {
        let transform = try Transform(parsing: "translate(10, 20) rotate(90) scale(2 3) skewX(0) skewY(0) matrix(1 0 0 1 0 0)")
        #expect(transform.operations == [
            .translate(x: 10, y: 20), .rotate(degrees: 90, center: nil), .scale(x: 2, y: 3), .skewX(degrees: 0), .skewY(degrees: 0),
            .matrix(.identity),
        ])
    }

    @Test
    func `short forms fill in`() throws {
        #expect(try Transform(parsing: "translate(5)").operations == [.translate(x: 5, y: 0)])
        #expect(try Transform(parsing: "scale(2)").operations == [.scale(x: 2, y: 2)])
        #expect(try Transform(parsing: "rotate(45 1 2)").operations == [.rotate(degrees: 45, center: Point(x: 1, y: 2))])
    }

    @Test(arguments: ["translate(1 2 3)", "spin(4)", "rotate(", "scale()"])
    func `rejects bad transforms`(text: String) {
        #expect(throws: TransformError.self) {
            try Transform(parsing: text)
        }
    }

    @Test
    func `leftmost operation is outermost`() throws {
        let matrix = try Transform(parsing: "translate(10 0) scale(2)").matrix
        #expect(matrix.applying(to: Point(x: 1, y: 1)) == Point(x: 12, y: 2))
    }

    @Test
    func `rotation is clockwise with y down`() {
        let matrix = TransformOperation.rotate(degrees: 90, center: nil).matrix
        #expect(close(matrix.applying(to: Point(x: 1, y: 0)), Point(x: 0, y: 1)))
    }

    @Test
    func `rotation about a center keeps the center`() {
        let matrix = TransformOperation.rotate(degrees: 37, center: Point(x: 5, y: 7)).matrix
        #expect(close(matrix.applying(to: Point(x: 5, y: 7)), Point(x: 5, y: 7)))
    }

    @Test
    func `decodes every json form`() throws {
        let string = try element("{ circle: [0, 0, 1], transform: 'rotate(45)' }")
        let array = try element("{ circle: [0, 0, 1], transform: [{ translate: [1, 2] }, { scale: 2 }, { rotate: [10, 1, 1] }] }")
        let single = try element("{ circle: [0, 0, 1], transform: { rotate: 45 } }")
        #expect(string.transform == single.transform)
        #expect(array.transform?.operations == [.translate(x: 1, y: 2), .scale(x: 2, y: 2), .rotate(degrees: 10, center: Point(x: 1, y: 1))])
    }

    @Test
    func `bad json transforms name their place`() {
        #expect(elementFailure("{ circle: [0, 0, 1], transform: [{ rotate: 1 }, { spin: 2 }] }").hasPrefix("elements[0].transform[1]: a transform operation needs one of"))
        #expect(elementFailure("{ circle: [0, 0, 1], transform: { rotate: 1, scale: 2 } }") == "elements[0].transform: a transform operation has more than one type key: rotate, scale")
        #expect(elementFailure("{ circle: [0, 0, 1], transform: 'spin(3)' }") == "elements[0].transform: unknown transform operation 'spin'")
    }
}
