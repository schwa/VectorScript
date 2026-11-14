import Foundation
import Testing
@testable import VectorScript

struct InstanceTests {
    let defs = "{ dot: { circle: [0, 0, 2], fill: 'red' }, ring: { group: [{ use: 'dot' }, { use: 'dot', at: [5, 0] }] } }"

    @Test
    func `uses become instances of resolved definitions`() throws {
        let resolved = try document(elements: "{ use: 'dot', at: [1, 1] }, { use: 'dot', at: [9, 9], opacity: 0.5, clip: { rect: [0, 0, 4, 4] } }", defs: defs).resolved(keepingInstances: true)
        #expect(resolved.isResolved)
        #expect(resolved.defs.keys.sorted() == ["dot"])
        #expect(resolved.elements.map(\.content) == [.use(Use(name: "dot", at: Point(x: 1, y: 1))), .use(Use(name: "dot", at: Point(x: 9, y: 9)))])
        // Element-wide properties stay on the use.
        #expect(resolved.elements[1].opacity == 0.5)
        #expect(resolved.elements[1].clip != nil)
        guard case .element(let dot) = resolved.defs["dot"] else {
            Issue.record("no dot")
            return
        }
        #expect(dot.style.fill == .color(Color(red: 1, green: 0, blue: 0)))
        #expect(dot.style.strokeWidth == 1)
    }

    @Test
    func `different styles make different instances`() throws {
        let resolved = try document(elements: "{ use: 'dot' }, { use: 'dot', fill: 'blue' }, { group: [{ use: 'dot' }], stroke: 'black' }, { use: 'dot', fill: 'blue' }", defs: defs).resolved(keepingInstances: true)
        let names = resolved.elements.compactMap { element -> String? in
            switch element.content {
            case .use(let use): use.name
            case .group(let children):
                if case .use(let use) = children.first?.content {
                    use.name
                } else {
                    nil
                }
            default: nil
            }
        }
        #expect(names == ["dot", "dot-2", "dot-3", "dot-2"])
        #expect(resolved.defs.count == 3)
    }

    @Test
    func `nested uses stay instances`() throws {
        let resolved = try document(elements: "{ use: 'ring' }, { use: 'ring', at: [20, 0] }", defs: defs).resolved(keepingInstances: true)
        #expect(resolved.defs.keys.sorted() == ["dot", "ring"])
        guard case .element(let ring) = resolved.defs["ring"], case .group(let children) = ring.content else {
            Issue.record("no ring")
            return
        }
        #expect(children.map(\.content) == [.use(Use(name: "dot")), .use(Use(name: "dot", at: Point(x: 5, y: 0)))])
    }

    @Test
    func `the flat form is still the default`() throws {
        let resolved = try document(elements: "{ use: 'dot' }", defs: defs).resolved()
        #expect(resolved.defs.isEmpty)
        guard case .group = resolved.elements[0].content else {
            Issue.record("not expanded")
            return
        }
    }

    @Test
    func `instances round trip and flatten`() throws {
        let instanced = try document(elements: "{ use: 'ring', transform: 'rotate(10)' }, { use: 'dot', fill: 'green' }", defs: defs).resolved(keepingInstances: true)
        let reloaded = try Document(json: instanced.jsonData())
        #expect(reloaded == instanced)
        #expect(reloaded.isResolved)
        // Flattening an instanced document gives the same result as flattening the original.
        let original = try document(elements: "{ use: 'ring', transform: 'rotate(10)' }, { use: 'dot', fill: 'green' }", defs: defs)
        #expect(try reloaded.resolved().elements.count == original.resolved().elements.count)
    }

    @Test
    func `resolved documents reject leftovers`() throws {
        #expect(!(try document(elements: "{ use: 'dot', fill: 'blue' }", defs: defs).isResolved))
        let withPaint = try document(elements: "{ rect: [0, 0, 1, 1], fill: '$ink' }", defs: "{ ink: 'red' }").resolved(keepingInstances: true)
        // Paints are inlined, so no paint defs are left.
        #expect(withPaint.defs.isEmpty)
        #expect(withPaint.isResolved)
    }
}
