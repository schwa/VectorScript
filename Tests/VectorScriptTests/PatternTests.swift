import Foundation
import Testing
@testable import VectorScript

struct PatternTests {
    @Test
    func `decodes a pattern paint`() throws {
        let element = try element("{ rect: [0, 0, 10, 10], fill: { pattern: { size: [4, 2], transform: 'rotate(45)', elements: [{ rect: [0, 0, 2, 2] }] } } }")
        guard case .pattern(let pattern) = element.style.fill else {
            Issue.record("not a pattern")
            return
        }
        #expect(pattern.size == Size(width: 4, height: 2))
        #expect(pattern.transform?.operations == [.rotate(degrees: 45, center: nil)])
        #expect(pattern.elements.count == 1)
    }

    @Test
    func `rejects bad patterns`() {
        #expect(elementFailure("{ rect: [0, 0, 1, 1], fill: { pattern: { size: [0, 2], elements: [] } } }") == "elements[0].fill.pattern.size: a pattern's size must be positive")
        #expect(elementFailure("{ rect: [0, 0, 1, 1], fill: { pattern: { size: [1, 1], elements: [], tile: 1 } } }") == "elements[0].fill.pattern: unknown key 'tile'")
    }

    @Test
    func `checks references inside patterns`() {
        #expect(elementFailure("{ rect: [0, 0, 1, 1], fill: { pattern: { size: [1, 1], elements: [{ circle: [0, 0, 1], fill: '$ink' }] } } }") == "elements[0].fill.pattern.elements[0].fill: no paint named 'ink' in defs")
    }

    @Test
    func `rejects a pattern that paints with itself`() {
        let message = elementFailure("{ rect: [0, 0, 1, 1], fill: '$tiles' }", defs: "{ tiles: { pattern: { size: [1, 1], elements: [{ rect: [0, 0, 1, 1], fill: '$tiles' }] } } }")
        #expect(message.contains("pattern cycle: tiles -> tiles"))
    }

    @Test
    func `pattern contents resolve from the initial style`() throws {
        let resolved = try document(elements: "{ group: [{ rect: [0, 0, 10, 10], fill: '$tiles' }], stroke: 'red' }", defs: "{ ink: 'blue', tiles: { pattern: { size: [2, 2], transform: 'scale(2)', elements: [{ use: 'dot' }, { circle: [1, 1, 1], fill: '$ink' }] } }, dot: { rect: [0, 0, 1, 1] } }").resolved()
        #expect(resolved.isResolved)
        guard case .group(let children) = resolved.elements[0].content, case .pattern(let pattern) = children[0].style.fill else {
            Issue.record("no pattern")
            return
        }
        #expect(pattern.transform == Transform(matrix: Matrix(a: 2, b: 0, c: 0, d: 2, tx: 0, ty: 0)))
        #expect(pattern.elements[1].style.fill == .color(Color(red: 0, green: 0, blue: 1)))
        // The painted element's red stroke does not reach the tile's contents.
        #expect(pattern.elements[1].style.stroke == Paint.none)
    }

    @Test
    func `patterns round trip through json`() throws {
        let original = try document(elements: "{ rect: [0, 0, 10, 10], stroke: { pattern: { size: [3, 3], elements: [{ circle: [1, 1, 1], fill: 'red' }] } }, strokeWidth: 2 }")
        #expect(try Document(json: original.jsonData()) == original)
    }
}
