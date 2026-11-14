import CoreGraphics
import Foundation
import Testing
import VectorScript
import VectorScriptRender

struct FilterTests {
    func near(_ actual: [UInt8], _ expected: [UInt8], tolerance: Int = 3) -> Bool {
        zip(actual, expected).allSatisfy { abs(Int($0) - Int($1)) <= tolerance }
    }

    @Test
    func `blur spreads color past the edge`() throws {
        let sharp = try render("{ size: [60, 60], elements: [{ rect: [10, 10, 40, 40], fill: 'red' }] }")
        let blurred = try render("{ size: [60, 60], elements: [{ rect: [10, 10, 40, 40], fill: 'red', filter: { blur: 3 } }] }")
        #expect(sharp[54, 30][3] == 0)
        #expect(blurred[54, 30][3] > 0)
        #expect(blurred[50, 30][3] < 200)
        #expect(near(blurred[30, 30], [255, 0, 0, 255]))
    }

    @Test
    func `drop shadow appears at its offset under the element`() throws {
        let bitmap = try render("{ size: [40, 40], elements: [{ rect: [5, 5, 20, 20], fill: 'red', filter: { dropShadow: { offset: [10, 10], color: 'blue' } } }] }")
        #expect(near(bitmap[10, 10], [255, 0, 0, 255]))
        // Below and right of the rect, only the shadow shows.
        #expect(near(bitmap[30, 30], [0, 0, 255, 255]))
        #expect(bitmap[2, 35][3] == 0)
    }

    @Test
    func `color filters change colors`() throws {
        let gray = try render("{ size: [4, 4], elements: [{ rect: [0, 0, 4, 4], fill: '#ff0000', filter: { grayscale: 1 } }] }")[2, 2]
        #expect(abs(Int(gray[0]) - Int(gray[1])) <= 2 && abs(Int(gray[1]) - Int(gray[2])) <= 2)
        let inverted = try render("{ size: [4, 4], elements: [{ rect: [0, 0, 4, 4], fill: '#ff0000', filter: { invert: 1 } }] }")[2, 2]
        #expect(near(inverted, [0, 255, 255, 255]))
        let darker = try render("{ size: [4, 4], elements: [{ rect: [0, 0, 4, 4], fill: '#ffffff', filter: { brightness: 0.5 } }] }")[2, 2]
        #expect(near(darker, [128, 128, 128, 255]))
        let flat = try render("{ size: [4, 4], elements: [{ rect: [0, 0, 4, 4], fill: '#ff0000', filter: { contrast: 0 } }] }")[2, 2]
        #expect(near(flat, [128, 128, 128, 255]))
        let rotated = try render("{ size: [4, 4], elements: [{ rect: [0, 0, 4, 4], fill: '#ff0000', filter: { hueRotate: 120 } }] }")[2, 2]
        #expect(rotated[1] > rotated[0])
    }

    @Test
    func `filters apply in order`() throws {
        // Invert then brightness 0 is black; brightness 0 then invert is white.
        let black = try render("{ size: [4, 4], elements: [{ rect: [0, 0, 4, 4], fill: '#808080', filter: [{ invert: 1 }, { brightness: 0 }] }] }")[2, 2]
        let white = try render("{ size: [4, 4], elements: [{ rect: [0, 0, 4, 4], fill: '#808080', filter: [{ brightness: 0 }, { invert: 1 }] }] }")[2, 2]
        #expect(near(black, [0, 0, 0, 255]))
        #expect(near(white, [255, 255, 255, 255]))
    }

    @Test
    func `clip applies after the filter`() throws {
        // The shadow lands outside the clip, so it is cut off.
        let bitmap = try render("{ size: [40, 40], elements: [{ rect: [5, 5, 20, 20], fill: 'red', clip: { rect: [0, 0, 25, 25] }, filter: { dropShadow: { offset: [10, 10], color: 'blue' } } }] }")
        #expect(bitmap[30, 30][3] == 0)
    }

    @Test
    func `filters scale with the output`() throws {
        let bitmap = try render("{ size: [40, 20], elements: [{ rect: [0, 0, 20, 20], fill: 'red', filter: { blur: 3 } }] }", scale: 3)
        // Three times the pixels: the blur reaches three times as far.
        #expect(bitmap[72, 30][3] > 0)
        #expect(bitmap[90, 30][3] == 0)
    }

    @Test
    func `pdf output works`() throws {
        let document = try Document(json: Data("{ size: [20, 20], elements: [{ circle: [10, 10, 5], filter: { blur: 2 } }] }".utf8))
        #expect(try Renderer(document: document).data(format: .pdf).starts(with: Array("%PDF".utf8)))
    }
}
