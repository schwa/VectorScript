import CoreGraphics
import Foundation
import Testing
import VectorScript
import VectorScriptRender

struct Bitmap {
    let width: Int
    let height: Int
    let bytes: [UInt8]

    init(_ image: CGImage) {
        width = image.width
        height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let context = CGContext(data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        self.bytes = bytes
    }

    // RGBA at (x, y) with y down.
    subscript(x: Int, y: Int) -> [UInt8] {
        let offset = (y * width + x) * 4
        return Array(bytes[offset..<(offset + 4)])
    }
}

func render(_ json: String, scale: Double = 1) throws -> Bitmap {
    Bitmap(try Renderer(document: Document(json: Data(json.utf8))).cgImage(scale: scale))
}

struct RendererTests {
    let red: [UInt8] = [255, 0, 0, 255]
    let blue: [UInt8] = [0, 0, 255, 255]
    let clear: [UInt8] = [0, 0, 0, 0]

    @Test
    func `draws with y down`() throws {
        let bitmap = try render("{ size: [10, 10], elements: [{ rect: [0, 0, 10, 5], fill: 'red' }] }")
        #expect(bitmap[5, 1] == red)
        #expect(bitmap[5, 8] == clear)
    }

    @Test
    func `fills the background`() throws {
        let bitmap = try render("{ size: [4, 4], background: 'blue', elements: [] }")
        #expect(bitmap[0, 0] == blue)
        #expect(bitmap[3, 3] == blue)
    }

    @Test
    func `scale multiplies pixels`() throws {
        let bitmap = try render("{ size: [10, 20], elements: [] }", scale: 3)
        #expect(bitmap.width == 30)
        #expect(bitmap.height == 60)
    }

    @Test
    func `view box maps onto size`() throws {
        let bitmap = try render("{ size: [100, 100], viewBox: [50, 50, 10, 10], elements: [{ rect: [50, 50, 5, 10], fill: 'red' }] }")
        #expect(bitmap[25, 50] == red)
        #expect(bitmap[75, 50] == clear)
    }

    @Test
    func `meet letterboxes and slice crops`() throws {
        // A 10 x 10 view box with a red left half on a 40 x 20 canvas.
        let meet = try render("{ size: [40, 20], viewBox: [0, 0, 10, 10], preserveAspectRatio: 'xMidYMid meet', elements: [{ rect: [0, 0, 5, 10], fill: 'red' }] }")
        #expect(meet[5, 10] == clear)
        #expect(meet[15, 10] == red)
        #expect(meet[25, 10] == clear)
        let slice = try render("{ size: [40, 20], viewBox: [0, 0, 10, 10], preserveAspectRatio: 'xMinYMin slice', elements: [{ rect: [0, 0, 5, 10], fill: 'red' }, { rect: [0, 5, 10, 5], fill: 'blue' }] }")
        #expect(slice[5, 5] == red)
        #expect(slice[30, 5] == clear)
        // The blue lower half starts below the canvas, so none of it shows.
        #expect(!(0..<40).contains { slice[$0, 19] == blue })
    }

    @Test
    func `slice content stays inside the canvas`() throws {
        let document = try Document(json: Data("{ size: [20, 10], viewBox: [0, 0, 10, 10], preserveAspectRatio: 'xMidYMid slice', elements: [{ rect: [0, 0, 10, 10], fill: 'red' }] }".utf8))
        let image = try Renderer(document: document).cgImage()
        #expect(image.width == 20)
        #expect(image.height == 10)
        #expect(Bitmap(image)[19, 9] == red)
    }

    @Test
    func `size override keeps the view box`() throws {
        let document = try Document(json: Data("{ size: [10, 10], elements: [{ rect: [0, 0, 5, 10], fill: 'red' }] }".utf8))
        let bitmap = Bitmap(try Renderer(document: document).cgImage(size: Size(width: 40, height: 40)))
        #expect(bitmap.width == 40)
        #expect(bitmap[10, 20] == red)
        #expect(bitmap[30, 20] == clear)
    }

    @Test
    func `circle covers its center not its corner`() throws {
        let bitmap = try render("{ size: [20, 20], elements: [{ circle: [10, 10, 8], fill: 'red' }] }")
        #expect(bitmap[10, 10] == red)
        #expect(bitmap[1, 1] == clear)
    }

    @Test
    func `evenodd leaves the hole empty`() throws {
        let path = "M 0 0 H 30 V 30 H 0 Z M 10 10 H 20 V 20 H 10 Z"
        let nonzero = try render("{ size: [30, 30], elements: [{ path: '\(path)', fill: 'red' }] }")
        let evenodd = try render("{ size: [30, 30], elements: [{ path: '\(path)', fill: 'red', fillRule: 'evenodd' }] }")
        #expect(nonzero[15, 15] == red)
        #expect(evenodd[15, 15] == clear)
        #expect(evenodd[5, 5] == red)
    }

    @Test
    func `transforms move shapes`() throws {
        let bitmap = try render("{ size: [20, 20], elements: [{ rect: [0, 0, 5, 5], fill: 'red', transform: 'translate(10 10)' }] }")
        #expect(bitmap[12, 12] == red)
        #expect(bitmap[2, 2] == clear)
    }

    @Test
    func `clip excludes outside`() throws {
        let bitmap = try render("{ size: [20, 20], elements: [{ rect: [0, 0, 20, 20], fill: 'red', clip: { rect: [0, 0, 10, 20] } }] }")
        #expect(bitmap[5, 10] == red)
        #expect(bitmap[15, 10] == clear)
    }

    @Test
    func `group opacity composites once`() throws {
        let bitmap = try render("{ size: [10, 10], elements: [{ group: [{ rect: [0, 0, 10, 10], fill: 'red' }, { rect: [0, 0, 10, 10], fill: 'red' }], opacity: 0.5 }] }")
        let alpha = Int(bitmap[5, 5][3])
        #expect(abs(alpha - 128) <= 1)
    }

    @Test
    func `strokes draw outside the fill`() throws {
        let bitmap = try render("{ size: [20, 20], elements: [{ rect: [5, 5, 10, 10], fill: 'none', stroke: 'blue', strokeWidth: 4 }] }")
        #expect(bitmap[4, 10] == blue)
        #expect(bitmap[10, 10] == clear)
    }

    @Test
    func `gradients vary across the box`() throws {
        let bitmap = try render("{ size: [100, 10], elements: [{ rect: [0, 0, 100, 10], fill: { linearGradient: { stops: [[0, 'red'], [1, 'blue']] } } }] }")
        #expect(bitmap[2, 5][0] > 240)
        #expect(bitmap[97, 5][2] > 240)
    }

    @Test
    func `uses draw their definition`() throws {
        let bitmap = try render("{ size: [20, 20], defs: { dot: { rect: [0, 0, 4, 4] } }, elements: [{ use: 'dot', at: [10, 10], fill: 'red' }] }")
        #expect(bitmap[12, 12] == red)
        #expect(bitmap[2, 2] == clear)
    }

    @Test
    func `multiply darkens what is behind`() throws {
        // Yellow times cyan is green.
        let bitmap = try render("{ size: [10, 10], elements: [{ rect: [0, 0, 10, 10], fill: '#ffff00' }, { rect: [0, 0, 10, 10], fill: '#00ffff', blendMode: 'multiply' }] }")
        #expect(bitmap[5, 5] == [0, 255, 0, 255])
    }

    @Test
    func `screen and difference blend as css does`() throws {
        let screen = try render("{ size: [10, 10], elements: [{ rect: [0, 0, 10, 10], fill: '#800000' }, { rect: [0, 0, 10, 10], fill: '#008000', blendMode: 'screen' }] }")
        #expect(screen[5, 5] == [128, 128, 0, 255])
        let difference = try render("{ size: [10, 10], elements: [{ rect: [0, 0, 10, 10], fill: '#ffffff' }, { rect: [0, 0, 10, 10], fill: '#ff0000', blendMode: 'difference' }] }")
        #expect(difference[5, 5] == [0, 255, 255, 255])
    }

    @Test
    func `a blended group composites as one`() throws {
        // Inside the group the second rect draws normally over the first; only the result multiplies.
        let bitmap = try render("{ size: [10, 10], elements: [{ rect: [0, 0, 10, 10], fill: '#ffff00' }, { group: [{ rect: [0, 0, 10, 10], fill: '#ff00ff' }, { rect: [0, 0, 10, 10], fill: '#00ffff' }], blendMode: 'multiply' }] }")
        #expect(bitmap[5, 5] == [0, 255, 0, 255])
    }

    @Test
    func `blend mode and opacity combine`() throws {
        let bitmap = try render("{ size: [10, 10], elements: [{ rect: [0, 0, 10, 10], fill: '#ffffff' }, { rect: [0, 0, 10, 10], fill: '#000000', blendMode: 'multiply', opacity: 0.5 }] }")
        #expect(abs(Int(bitmap[5, 5][0]) - 128) <= 1)
    }

    @Test
    func `a luminance mask shows white and hides black`() throws {
        let bitmap = try render("{ size: [20, 10], elements: [{ rect: [0, 0, 20, 10], fill: 'red', mask: { elements: [{ rect: [0, 0, 10, 10], fill: 'white' }, { rect: [10, 0, 10, 10], fill: 'black' }] } }] }")
        #expect(bitmap[5, 5] == red)
        #expect(bitmap[15, 5] == clear)
    }

    @Test
    func `a gray luminance mask shows part of the element`() throws {
        let bitmap = try render("{ size: [10, 10], elements: [{ rect: [0, 0, 10, 10], fill: 'red', mask: { elements: [{ rect: [0, 0, 10, 10], fill: '#808080' }] } }] }")
        let alpha = Int(bitmap[5, 5][3])
        #expect(abs(alpha - 128) <= 2)
    }

    @Test
    func `an alpha mask ignores color`() throws {
        let bitmap = try render("{ size: [20, 10], elements: [{ rect: [0, 0, 20, 10], fill: 'red', mask: { mode: 'alpha', elements: [{ rect: [0, 0, 10, 10], fill: 'black' }] } }] }")
        #expect(bitmap[5, 5] == red)
        #expect(bitmap[15, 5] == clear)
    }

    @Test
    func `a mask is in the element's transformed space`() throws {
        let bitmap = try render("{ size: [40, 20], elements: [{ rect: [0, 0, 20, 20], fill: 'red', transform: 'translate(20 0)', mask: { elements: [{ rect: [0, 0, 10, 20], fill: 'white' }] } }] }")
        #expect(bitmap[25, 10] == red)
        #expect(bitmap[35, 10] == clear)
        #expect(bitmap[5, 10] == clear)
    }

    @Test
    func `masks work at scale and in pdf`() throws {
        let json = "{ size: [20, 10], elements: [{ rect: [0, 0, 20, 10], fill: 'red', mask: { elements: [{ rect: [0, 0, 10, 10], fill: 'white' }] } }] }"
        let bitmap = try render(json, scale: 3)
        #expect(bitmap[15, 15] == red)
        #expect(bitmap[45, 15] == clear)
        let pdf = try Renderer(document: Document(json: Data(json.utf8))).data(format: .pdf)
        #expect(pdf.starts(with: Array("%PDF".utf8)))
    }

    @Test
    func `patterns repeat their tile`() throws {
        // A 10 x 10 tile with a red 5 x 5 square in its top left corner.
        let bitmap = try render("{ size: [40, 20], elements: [{ rect: [0, 0, 40, 20], fill: { pattern: { size: [10, 10], elements: [{ rect: [0, 0, 5, 5], fill: 'red' }] } } }] }")
        #expect(bitmap[2, 2] == red)
        #expect(bitmap[32, 12] == red)
        #expect(bitmap[7, 2] == clear)
        #expect(bitmap[32, 17] == clear)
    }

    @Test
    func `pattern tiles clip their contents`() throws {
        let bitmap = try render("{ size: [20, 10], elements: [{ rect: [0, 0, 20, 10], fill: { pattern: { size: [10, 10], elements: [{ rect: [5, 0, 10, 10], fill: 'red' }] } } }] }")
        #expect(bitmap[2, 5] == clear)
        #expect(bitmap[7, 5] == red)
        #expect(bitmap[12, 5] == clear)
    }

    @Test
    func `pattern transforms move the tiles`() throws {
        let bitmap = try render("{ size: [20, 20], elements: [{ rect: [0, 0, 20, 20], fill: { pattern: { size: [20, 20], transform: 'translate(10 10)', elements: [{ rect: [0, 0, 5, 5], fill: 'red' }] } } }] }")
        #expect(bitmap[2, 2] == clear)
        #expect(bitmap[12, 12] == red)
    }

    @Test
    func `tiny pattern tiles are an error`() throws {
        let document = try Document(json: Data("{ size: [1000, 1000], elements: [{ rect: [0, 0, 1000, 1000], fill: { pattern: { size: [0.5, 0.5], elements: [] } } }] }".utf8))
        #expect(throws: RenderError.self) {
            try Renderer(document: document).cgImage()
        }
    }

    @Test
    func `a use clip ignores at`() throws {
        let bitmap = try render("{ size: [20, 20], defs: { box: { rect: [0, 0, 20, 20] } }, elements: [{ use: 'box', at: [5, 0], fill: 'red', clip: { rect: [0, 0, 10, 20] } }] }")
        #expect(bitmap[2, 10] == clear)
        #expect(bitmap[7, 10] == red)
        #expect(bitmap[15, 10] == clear)
    }

    @Test
    func `text draws ink near the baseline`() throws {
        let bitmap = try render("{ size: [100, 40], elements: [{ text: 'HH', at: [10, 30], fontSize: 30, fill: 'red' }] }")
        let inked = (0..<bitmap.width).contains { x in bitmap[x, 20][3] > 0 }
        #expect(inked)
        #expect(bitmap[50, 35][3] == 0)
    }

    // The x range covered by ink in row `y`.
    func inkExtent(_ bitmap: Bitmap, row y: Int) -> ClosedRange<Int>? {
        let inked = (0..<bitmap.width).filter { bitmap[$0, y][3] > 0 }
        guard let first = inked.first, let last = inked.last else {
            return nil
        }
        return first...last
    }

    @Test
    func `letter spacing widens text`() throws {
        let plain = try render("{ size: [200, 40], elements: [{ text: 'HHHH', at: [10, 30], fontSize: 20 }] }")
        let spaced = try render("{ size: [200, 40], elements: [{ text: 'HHHH', at: [10, 30], fontSize: 20, letterSpacing: 10 }] }")
        let plainExtent = try #require(inkExtent(plain, row: 20))
        let spacedExtent = try #require(inkExtent(spaced, row: 20))
        // Three gaps of 10 points each.
        #expect(abs(spacedExtent.count - plainExtent.count - 30) <= 2)
    }

    @Test
    func `letter spacing keeps middle anchored text centered`() throws {
        let bitmap = try render("{ size: [200, 40], elements: [{ text: 'HHHH', at: [100, 30], anchor: 'middle', fontSize: 20, letterSpacing: 12 }] }")
        let extent = try #require(inkExtent(bitmap, row: 20))
        let center = Double(extent.lowerBound + extent.upperBound) / 2
        #expect(abs(center - 100) <= 2)
    }

    @Test
    func `an unknown font is an error`() throws {
        let document = try Document(json: Data("{ size: [10, 10], elements: [{ text: 'A', at: [0, 5], font: 'NoSuchFont-Regular' }] }".utf8))
        #expect(throws: RenderError.unknownFont("NoSuchFont-Regular")) {
            try Renderer(document: document).cgImage()
        }
    }

    @Test
    func `writes every format`() throws {
        let document = try Document(json: Data("{ size: [8, 8], elements: [{ circle: [4, 4, 3] }] }".utf8))
        let renderer = try Renderer(document: document)
        #expect(try renderer.data(format: .png).starts(with: [0x89, 0x50, 0x4e, 0x47]))
        #expect(try renderer.data(format: .jpeg).starts(with: [0xff, 0xd8]))
        #expect(try renderer.data(format: .pdf).starts(with: Array("%PDF".utf8)))
    }
}
