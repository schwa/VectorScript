import Foundation
import Testing
@testable import VectorScript

struct RasterImageTests {
    @Test
    func `decodes an image element`() throws {
        let placed = try element("{ image: 'wood.png', at: [1, 2], size: [30, 40], opacity: 0.5 }")
        #expect(placed.content == .image(RasterImage(source: "wood.png", at: Point(x: 1, y: 2), size: Size(width: 30, height: 40))))
        #expect(placed.opacity == 0.5)
        let plain = try element("{ image: 'wood.png' }")
        #expect(plain.content == .image(RasterImage(source: "wood.png")))
    }

    @Test
    func `rejects bad image elements`() {
        #expect(elementFailure("{ image: 'a.png', size: [0, 4] }") == "elements[0].size: an image's size must be positive")
        #expect(elementFailure("{ image: 'a.png', anchor: 'middle' }") == "elements[0]: unknown key 'anchor'")
        #expect(elementFailure("{ image: 'a.png', fill: 'red' }") == "elements[0]: unknown key 'fill'")
    }

    @Test
    func `locates sources`() throws {
        let base = URL(filePath: "/art/panels/door.json5")
        #expect(try RasterImage(source: "wood.png").location(relativeTo: base) == .file(URL(filePath: "/art/panels/wood.png")))
        #expect(try RasterImage(source: "../shared/wood.png").location(relativeTo: base) == .file(URL(filePath: "/art/shared/wood.png")))
        #expect(try RasterImage(source: "/tmp/wood.png").location(relativeTo: base) == .file(URL(filePath: "/tmp/wood.png")))
        #expect(try RasterImage(source: "data:image/png;base64,AAEC").location(relativeTo: nil) == .data(Data([0, 1, 2])))
    }

    @Test
    func `rejects unusable sources`() {
        #expect(throws: RasterImage.SourceError.relativePathWithoutBase("wood.png")) {
            try RasterImage(source: "wood.png").location(relativeTo: nil)
        }
        #expect(throws: RasterImage.SourceError.badDataURI) {
            try RasterImage(source: "data:image/png,AAEC").location(relativeTo: nil)
        }
    }

    @Test
    func `contents of url sets the base url`() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "RasterImageTests-\(UUID()).json5")
        try Data("{ size: [1, 1], elements: [] }".utf8).write(to: url)
        #expect(try Document(contentsOf: url).baseURL == url)
    }

    @Test
    func `images resolve without style and round trip`() throws {
        let original = try document(elements: "{ group: [{ image: 'a.png', at: [1, 1] }], fill: 'red' }")
        let resolved = try original.resolved()
        #expect(resolved.isResolved)
        guard case .group(let children) = resolved.elements[0].content else {
            Issue.record("not a group")
            return
        }
        #expect(children[0].style.isEmpty)
        #expect(try Document(json: original.jsonData()) == original)
    }
}
