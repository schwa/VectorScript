import Testing
@testable import VectorScript

struct ResolveTests {
    let red = Paint.color(Color(red: 1, green: 0, blue: 0))
    let blue = Paint.color(Color(red: 0, green: 0, blue: 1))

    @Test
    func `shapes get the initial style`() throws {
        let resolved = try document(elements: "{ circle: [0, 0, 1] }").resolved()
        var expected = Style.initial
        expected.font = nil
        expected.fontSize = nil
        expected.letterSpacing = nil
        #expect(resolved.elements[0].style == expected)
        #expect(resolved.isResolved)
    }

    @Test
    func `groups pass style down and keep none`() throws {
        let resolved = try document(elements: "{ group: [{ circle: [0, 0, 1] }, { circle: [0, 0, 1], fill: 'blue' }], fill: 'red', strokeWidth: 3, opacity: 0.5 }").resolved()
        guard case .group(let children) = resolved.elements[0].content else {
            Issue.record("not a group")
            return
        }
        #expect(resolved.elements[0].style.isEmpty)
        #expect(resolved.elements[0].opacity == 0.5)
        #expect(children[0].style.fill == red)
        #expect(children[0].style.strokeWidth == 3)
        #expect(children[1].style.fill == blue)
        #expect(children[0].opacity == nil)
    }

    @Test
    func `text inherits fonts`() throws {
        let resolved = try document(elements: "{ group: [{ text: 'A', at: [0, 0] }], font: 'Menlo', fontSize: 9 }").resolved()
        guard case .group(let children) = resolved.elements[0].content else {
            Issue.record("not a group")
            return
        }
        #expect(children[0].style.font == "Menlo")
        #expect(children[0].style.fontSize == 9)
    }

    @Test
    func `letter spacing inherits and defaults to zero`() throws {
        let resolved = try document(elements: "{ group: [{ text: 'A', at: [0, 0] }, { circle: [0, 0, 1] }], letterSpacing: 2 }, { text: 'B', at: [0, 0] }").resolved()
        guard case .group(let children) = resolved.elements[0].content else {
            Issue.record("not a group")
            return
        }
        #expect(children[0].style.letterSpacing == 2)
        #expect(children[1].style.letterSpacing == nil)
        #expect(resolved.elements[1].style.letterSpacing == 0)
        #expect(try Document(json: resolved.jsonData()) == resolved)
    }

    @Test
    func `references are replaced`() throws {
        let resolved = try document(elements: "{ rect: [0, 0, 1, 1], fill: '$warm', stroke: '$warm' }", defs: "{ warm: 'red' }").resolved()
        #expect(resolved.elements[0].style.fill == red)
        #expect(resolved.elements[0].style.stroke == red)
        #expect(resolved.defs.isEmpty)
    }

    @Test
    func `uses expand with overrides and placement`() throws {
        let resolved = try document(elements: "{ use: 'dot', at: [10, 20], fill: 'blue' }, { use: 'dot' }", defs: "{ dot: { circle: [0, 0, 1], fill: 'red' } }").resolved()
        guard case .group(let outer) = resolved.elements[0].content, case .group(let placed) = outer[0].content, case .group(let plain) = resolved.elements[1].content else {
            Issue.record("uses are not groups")
            return
        }
        #expect(outer[0].transform == Transform(matrix: Matrix(a: 1, b: 0, c: 0, d: 1, tx: 10, ty: 20)))
        #expect(placed[0].style.fill == blue)
        #expect(resolved.elements[0].transform == nil)
        #expect(plain[0].style.fill == red)
        #expect(resolved.elements[1].transform == nil)
    }

    @Test
    func `transforms become one matrix`() throws {
        let resolved = try document(elements: "{ circle: [0, 0, 1], transform: 'translate(10 0) scale(2)' }").resolved()
        #expect(resolved.elements[0].transform == Transform(matrix: Matrix(a: 2, b: 0, c: 0, d: 2, tx: 10, ty: 0)))
    }

    @Test
    func `a resolved document stays resolved through json`() throws {
        let resolved = try document(elements: "{ group: [{ use: 'dot' }], fill: '$warm', transform: 'rotate(10)' }", defs: "{ warm: 'red', dot: { circle: [0, 0, 1] } }").resolved()
        let reloaded = try Document(json: resolved.jsonData())
        #expect(reloaded == resolved)
        #expect(reloaded.isResolved)
        #expect(try reloaded.resolved() == resolved)
    }

    @Test
    func `authored documents are not resolved`() throws {
        #expect(!(try document(elements: "{ circle: [0, 0, 1] }").isResolved))
        #expect(!(try document(elements: "{ group: [], fill: 'red' }").isResolved))
    }
}
