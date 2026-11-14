import CoreGraphics
import Foundation
import SwiftUI
import Testing
import VectorScript
@testable import VectorScriptSwiftUI

@MainActor
struct VectorScriptViewTests {
    func pixels(_ view: some View, size: CGSize) throws -> (CGImage, [UInt8]) {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = 1
        let image = try #require(renderer.cgImage)
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let context = try #require(CGContext(data: &bytes, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return (image, bytes)
    }

    func pixel(_ bytes: [UInt8], width: Int, x: Int, y: Int) -> [UInt8] {
        let offset = (y * width + x) * 4
        return Array(bytes[offset..<(offset + 4)])
    }

    func document(_ json: String) throws -> VectorScript.Document {
        try VectorScript.Document(json: Data(json.utf8))
    }

    @Test
    func `draws the document upright`() throws {
        let view = VectorScriptView(try document("{ size: [20, 20], elements: [{ rect: [0, 0, 20, 10], fill: 'red' }] }"))
        let (image, bytes) = try pixels(view, size: CGSize(width: 20, height: 20))
        #expect(pixel(bytes, width: image.width, x: 10, y: 3) == [255, 0, 0, 255])
        #expect(pixel(bytes, width: image.width, x: 10, y: 16)[3] == 0)
    }

    @Test
    func `scales to the space it gets`() throws {
        let view = VectorScriptView(try document("{ size: [10, 10], elements: [{ rect: [0, 0, 5, 10], fill: 'blue' }] }"))
        let (image, bytes) = try pixels(view, size: CGSize(width: 40, height: 40))
        #expect(image.width == 40)
        #expect(pixel(bytes, width: image.width, x: 10, y: 20) == [0, 0, 255, 255])
        #expect(pixel(bytes, width: image.width, x: 30, y: 20)[3] == 0)
    }

    @Test
    func `render errors show in the view`() throws {
        let view = VectorScriptView(try document("{ size: [40, 20], elements: [{ image: '/nonexistent.png' }] }"))
        let (image, bytes) = try pixels(view, size: CGSize(width: 40, height: 20))
        // The red frame of the error panel.
        let edge = pixel(bytes, width: image.width, x: 20, y: 0)
        #expect(edge[0] > 200 && edge[1] < 80)
    }

    @Test
    func `read errors show in the view`() throws {
        let view = VectorScriptView(contentsOf: URL(filePath: "/nonexistent/doc.json5"))
        let (image, bytes) = try pixels(view, size: CGSize(width: 40, height: 20))
        let edge = pixel(bytes, width: image.width, x: 20, y: 0)
        #expect(edge[0] > 200 && edge[1] < 80)
    }
}
