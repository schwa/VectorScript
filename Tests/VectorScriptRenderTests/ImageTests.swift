import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
import VectorScript
import VectorScriptRender

struct ImageTests {
    let red: [UInt8] = [255, 0, 0, 255]
    let blue: [UInt8] = [0, 0, 255, 255]
    let clear: [UInt8] = [0, 0, 0, 0]

    // A 2 x 2 PNG: red top row, blue bottom row.
    static let pngData: Data = {
        var pixels: [UInt8] = [255, 0, 0, 255, 255, 0, 0, 255, 0, 0, 255, 255, 0, 0, 255, 255]
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let context = CGContext(data: &pixels, width: 2, height: 2, bitsPerComponent: 8, bytesPerRow: 8, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let image = context.makeImage()!
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data as CFMutableData, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
        return data as Data
    }()

    static var dataURI: String {
        "data:image/png;base64," + pngData.base64EncodedString()
    }

    @Test
    func `draws an image upright at its pixel size`() throws {
        let bitmap = try render("{ size: [4, 4], elements: [{ image: '\(Self.dataURI)', at: [1, 1] }] }")
        #expect(bitmap[1, 1] == red)
        #expect(bitmap[1, 2] == blue)
        #expect(bitmap[3, 3] == clear)
    }

    @Test
    func `size scales the image`() throws {
        let bitmap = try render("{ size: [20, 20], elements: [{ image: '\(Self.dataURI)', size: [20, 20] }] }")
        #expect(bitmap[10, 3] == red)
        #expect(bitmap[10, 16] == blue)
    }

    @Test
    func `relative paths load next to the document`() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "ImageTests-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Self.pngData.write(to: directory.appending(path: "tile.png"))
        let url = directory.appending(path: "doc.json5")
        try Data("{ size: [2, 2], elements: [{ image: 'tile.png' }] }".utf8).write(to: url)
        let bitmap = Bitmap(try Renderer(document: Document(contentsOf: url)).cgImage())
        #expect(bitmap[0, 0] == red)
        #expect(bitmap[0, 1] == blue)
    }

    @Test
    func `opacity and clip apply to images`() throws {
        let bitmap = try render("{ size: [20, 20], elements: [{ image: '\(Self.dataURI)', size: [20, 20], opacity: 0.5, clip: { rect: [0, 0, 10, 20] } }] }")
        #expect(abs(Int(bitmap[5, 3][3]) - 128) <= 1)
        #expect(bitmap[15, 3] == clear)
    }

    @Test
    func `a missing image is an error`() throws {
        let document = try Document(json: Data("{ size: [2, 2], elements: [{ image: '/nonexistent/tile.png' }] }".utf8))
        #expect(throws: RenderError.cannotLoadImage(source: "/nonexistent/tile.png", reason: "no file at /nonexistent/tile.png")) {
            try Renderer(document: document).cgImage()
        }
    }

    @Test
    func `data that is not an image is an error`() throws {
        let document = try Document(json: Data("{ size: [2, 2], elements: [{ image: 'data:image/png;base64,AAEC' }] }".utf8))
        #expect(throws: RenderError.self) {
            try Renderer(document: document).cgImage()
        }
    }
}
