import Foundation
import Testing
@testable import VectorScript

struct MarkerTests {
    func close(_ a: Double, _ b: Double) -> Bool {
        abs(a - b) < 1e-9
    }

    @Test
    func `decodes every marker form`() throws {
        let marked = try element("{ path: 'M 0 0 L 10 0', markerStart: 'dot', markerMid: { name: 'dot', orient: 'auto-start-reverse' }, markerEnd: { element: { circle: [0, 0, 1] }, orient: 45 } }")
        #expect(marked.style.markerStart == Marker(.named("dot")))
        #expect(marked.style.markerMid == Marker(.named("dot"), orientation: .autoStartReverse))
        guard case .element = marked.style.markerEnd?.source else {
            Issue.record("not inline")
            return
        }
        #expect(marked.style.markerEnd?.orientation == .angle(45))
        #expect(try element("{ line: [0, 0, 1, 1], markerEnd: 'none' }").style.markerEnd == Marker(.none))
    }

    func element(_ json: String, defs: String = "{ dot: { circle: [0, 0, 1] } }") throws -> Element {
        try document(elements: json, defs: defs).elements[0]
    }

    @Test
    func `rejects bad markers`() {
        #expect(elementFailure("{ line: [0, 0, 1, 1], markerEnd: 'arrow' }") == "elements[0].markerEnd: no element named 'arrow' in defs")
        #expect(elementFailure("{ line: [0, 0, 1, 1], markerEnd: 'ink' }", defs: "{ ink: 'red' }") == "elements[0].markerEnd: 'ink' is a paint, not an element")
        #expect(elementFailure("{ line: [0, 0, 1, 1], markerEnd: { name: 'a', orient: 'sideways' } }", defs: "{ a: { circle: [0, 0, 1] } }").hasPrefix("elements[0].markerEnd.orient: unknown orient 'sideways'"))
        #expect(elementFailure("{ line: [0, 0, 1, 1], markerEnd: { name: 'a', element: { circle: [0, 0, 1] } } }").contains("more than one type key"))
        #expect(elementFailure("{ line: [0, 0, 1, 1], markerEnd: 'a' }", defs: "{ a: { path: 'M 0 0 L 1 0', markerEnd: 'a' } }").contains("marker cycle: a -> a"))
    }

    @Test
    func `line and polyline vertices`() {
        let line = Shape.line(from: Point(x: 0, y: 0), to: Point(x: 0, y: 10)).markerVertices
        #expect(line.map(\.position) == [.start, .end])
        #expect(line.allSatisfy { close($0.angle, 90) })
        let corner = Shape.polyline([Point(x: 0, y: 0), Point(x: 10, y: 0), Point(x: 10, y: 10)]).markerVertices
        #expect(corner.map(\.position) == [.start, .mid, .end])
        #expect(close(corner[0].angle, 0))
        #expect(close(corner[1].angle, 45))
        #expect(close(corner[2].angle, 90))
    }

    @Test
    func `polygon closes back to the start`() {
        let triangle = Shape.polygon([Point(x: 0, y: 0), Point(x: 10, y: 0), Point(x: 0, y: 10)]).markerVertices
        #expect(triangle.count == 4)
        #expect(triangle.last?.point == Point(x: 0, y: 0))
        #expect(triangle.last?.position == .end)
    }

    @Test
    func `curve vertices use their tangents`() throws {
        let cubic = Shape.path(try PathData(parsing: "M 0 0 C 0 10 10 10 10 0")).markerVertices
        #expect(close(cubic[0].angle, 90))
        #expect(close(cubic[1].angle, -90))
        let arc = Shape.path(try PathData(parsing: "M 0 0 A 5 5 0 0 1 10 0")).markerVertices
        // A clockwise half circle with y down leaves going up and arrives going down.
        #expect(close(arc[0].angle, -90))
        #expect(close(arc[1].angle, 90))
    }

    @Test
    func `mid angles take the short way round`() {
        // In heading 170 degrees, out heading -170: halfway is 180, not 0.
        let shape = Shape.polyline([Point(x: 10, y: -1.7632698), Point(x: 0, y: 0), Point(x: -10, y: -1.7632698)])
        let mid = shape.markerVertices[1]
        #expect(abs(abs(mid.angle) - 180) < 0.01)
    }

    @Test
    func `markers resolve inline from the initial style`() throws {
        let resolved = try document(elements: "{ group: [{ path: 'M 0 0 L 10 0' }, { circle: [0, 0, 1] }, { text: 'A', at: [0, 0] }], markerEnd: 'dot', fill: 'red' }", defs: "{ dot: { circle: [0, 0, 1] } }").resolved()
        #expect(resolved.isResolved)
        guard case .group(let children) = resolved.elements[0].content, case .element(let content) = children[0].style.markerEnd?.source else {
            Issue.record("no inline marker")
            return
        }
        #expect(content.style.fill == .color(.black))
        #expect(children[1].style.markerEnd == nil)
        #expect(children[2].style.markerEnd == nil)
        #expect(try Document(json: resolved.jsonData()) == resolved)
    }

    @Test
    func `none cancels an inherited marker`() throws {
        let resolved = try document(elements: "{ group: [{ line: [0, 0, 1, 0], markerEnd: 'none' }], markerEnd: 'dot' }", defs: "{ dot: { circle: [0, 0, 1] } }").resolved()
        guard case .group(let children) = resolved.elements[0].content else {
            Issue.record("not a group")
            return
        }
        #expect(children[0].style.markerEnd == nil)
    }
}
