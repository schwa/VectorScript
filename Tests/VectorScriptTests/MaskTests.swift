import Foundation
import Testing
@testable import VectorScript

struct MaskTests {
    @Test
    func `decodes a mask`() throws {
        let luminance = try element("{ rect: [0, 0, 10, 10], mask: { elements: [{ circle: [5, 5, 5], fill: 'white' }] } }")
        #expect(luminance.mask?.mode == .luminance)
        #expect(luminance.mask?.elements.count == 1)
        let alpha = try element("{ rect: [0, 0, 10, 10], mask: { mode: 'alpha', elements: [] } }")
        #expect(alpha.mask?.mode == .alpha)
    }

    @Test
    func `rejects bad masks`() {
        #expect(elementFailure("{ rect: [0, 0, 1, 1], mask: { elements: [], shape: 1 } }") == "elements[0].mask: unknown key 'shape'")
        #expect(elementFailure("{ rect: [0, 0, 1, 1], mask: { elements: [{ use: 'nope' }] } }") == "elements[0].mask.elements[0].use: no element named 'nope' in defs")
    }

    @Test
    func `mask contents resolve from the initial style`() throws {
        let resolved = try document(elements: "{ group: [{ rect: [0, 0, 10, 10], mask: { elements: [{ use: 'spot' }] } }], fill: 'red' }", defs: "{ spot: { circle: [5, 5, 5] } }").resolved()
        #expect(resolved.isResolved)
        guard case .group(let children) = resolved.elements[0].content, let mask = children[0].mask, case .group(let spot) = mask.elements[0].content else {
            Issue.record("no mask")
            return
        }
        // Black, the initial fill, not the group's red.
        #expect(spot[0].style.fill == .color(.black))
    }

    @Test
    func `masks round trip through json`() throws {
        let original = try document(elements: "{ rect: [0, 0, 10, 10], mask: { mode: 'alpha', elements: [{ circle: [5, 5, 5], fill: '#fff8' }] } }")
        #expect(try Document(json: original.jsonData()) == original)
    }
}
