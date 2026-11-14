import Testing
@testable import VectorScript

struct PathDataTests {
    func p(_ x: Double, _ y: Double) -> Point {
        Point(x: x, y: y)
    }

    @Test
    func `parses absolute commands`() throws {
        let path = try PathData(parsing: "M 10 20 L 30 40 H 50 V 60 C 1 2 3 4 5 6 Q 7 8 9 10 Z")
        #expect(path.segments == [
            .move(to: p(10, 20)), .line(to: p(30, 40)), .line(to: p(50, 40)), .line(to: p(50, 60)),
            .cubic(control1: p(1, 2), control2: p(3, 4), to: p(5, 6)), .quadratic(control: p(7, 8), to: p(9, 10)), .close,
        ])
    }

    @Test
    func `parses relative commands`() throws {
        let path = try PathData(parsing: "m 10 10 l 5 0 h 5 v 5 c 1 1 2 2 3 3 q 1 0 2 0 z l 1 1")
        #expect(path.segments == [
            .move(to: p(10, 10)), .line(to: p(15, 10)), .line(to: p(20, 10)), .line(to: p(20, 15)),
            .cubic(control1: p(21, 16), control2: p(22, 17), to: p(23, 18)), .quadratic(control: p(24, 18), to: p(25, 18)), .close,
            .line(to: p(11, 11)),
        ])
    }

    @Test
    func `repeats after move are lines`() throws {
        #expect(try PathData(parsing: "M 0 0 10 0 10 10").segments == [.move(to: p(0, 0)), .line(to: p(10, 0)), .line(to: p(10, 10))])
        #expect(try PathData(parsing: "m 1 1 2 0 0 2").segments == [.move(to: p(1, 1)), .line(to: p(3, 1)), .line(to: p(3, 3))])
    }

    @Test
    func `repeats other commands`() throws {
        #expect(try PathData(parsing: "M0 0 L1 1 2 2").segments == [.move(to: p(0, 0)), .line(to: p(1, 1)), .line(to: p(2, 2))])
    }

    @Test
    func `reads compact numbers`() throws {
        #expect(try PathData(parsing: "M1-2L.5.5").segments == [.move(to: p(1, -2)), .line(to: p(0.5, 0.5))])
        #expect(try PathData(parsing: "M1e2,-1.5E-1").segments == [.move(to: p(100, -0.15))])
        #expect(try PathData(parsing: "M+3 4").segments == [.move(to: p(3, 4))])
    }

    @Test
    func `reflects smooth controls`() throws {
        let cubic = try PathData(parsing: "M 0 0 C 0 10 10 10 10 0 S 20 -10 20 0")
        #expect(cubic.segments[2] == .cubic(control1: p(10, -10), control2: p(20, -10), to: p(20, 0)))
        let quadratic = try PathData(parsing: "M 0 0 Q 5 10 10 0 T 20 0")
        #expect(quadratic.segments[2] == .quadratic(control: p(15, -10), to: p(20, 0)))
        let bare = try PathData(parsing: "M 0 0 L 5 5 S 8 8 10 10")
        #expect(bare.segments[2] == .cubic(control1: p(5, 5), control2: p(8, 8), to: p(10, 10)))
    }

    @Test
    func `parses arcs with packed flags`() throws {
        let path = try PathData(parsing: "M 0 0 A 5 5 0 1 0 10 0 a5,5 30 0110,0")
        #expect(path.segments == [
            .move(to: p(0, 0)),
            .arc(radii: Size(width: 5, height: 5), rotation: 0, largeArc: true, sweep: false, to: p(10, 0)),
            .arc(radii: Size(width: 5, height: 5), rotation: 30, largeArc: false, sweep: true, to: p(20, 0)),
        ])
    }

    @Test
    func `a zero radius arc is a line`() throws {
        #expect(try PathData(parsing: "M 0 0 A 0 5 0 0 0 10 0").segments[1] == .line(to: p(10, 0)))
    }

    @Test(arguments: ["L 1 1", "M 1", "M 0 0 X 1", "M 0 0 A 1 1 0 2 0 1 1", "M 0 0 L 1 1 2"])
    func `rejects bad paths`(text: String) {
        #expect(throws: PathError.self) {
            try PathData(parsing: text)
        }
    }

    @Test
    func `writes absolute path data`() throws {
        let path = try PathData(parsing: "m 1 2 l 3 4 h 1.5 z")
        #expect(path.string == "M 1 2 L 4 6 L 5.5 6 Z")
        #expect(try PathData(parsing: path.string) == path)
    }

    @Test
    func `arc curves end on the end point`() {
        let curves = PathSegment.arcCurves(from: p(0, 0), radii: Size(width: 5, height: 5), rotation: 0, largeArc: true, sweep: true, to: p(10, 0))
        #expect(curves.count == 2)
        #expect(curves.last?.to == p(10, 0))
        #expect(abs(curves[0].to.x - 5) < 1e-9)
        #expect(abs(abs(curves[0].to.y) - 5) < 1e-9)
    }

    @Test
    func `arc radii scale up when too small`() {
        let curves = PathSegment.arcCurves(from: p(0, 0), radii: Size(width: 1, height: 1), rotation: 0, largeArc: false, sweep: true, to: p(10, 0))
        #expect(curves.count == 2)
        #expect(abs(curves[0].to.x - 5) < 1e-9)
    }

    @Test
    func `a bad path names its place`() {
        #expect(elementFailure("{ path: 'M 0 0 X' }").hasPrefix("elements[0].path: bad path: unknown command 'X'"))
    }
}
