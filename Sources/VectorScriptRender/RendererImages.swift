import CoreGraphics
import Foundation
import ImageIO
import VectorScript

extension Renderer {
    func draw(_ image: RasterImage, in context: CGContext) throws {
        let cgImage = try load(image)
        let size = image.size ?? Size(width: Double(cgImage.width), height: Double(cgImage.height))
        let rect = CGRect(x: image.at.x, y: image.at.y, width: size.width, height: size.height)
        context.saveGState()
        defer {
            context.restoreGState()
        }
        // Images are stored top row first; flip so they land upright in the y-down space.
        context.translateBy(x: 0, y: rect.minY + rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.interpolationQuality = .high
        context.draw(cgImage, in: rect)
    }

    func load(_ image: RasterImage) throws -> CGImage {
        let location: RasterImage.Location
        do {
            location = try image.location(relativeTo: document.baseURL)
        } catch {
            throw RenderError.cannotLoadImage(source: image.source, reason: error.description)
        }
        let source: CGImageSource?
        switch location {
        case .file(let url):
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw RenderError.cannotLoadImage(source: image.source, reason: "no file at \(url.path)")
            }
            source = CGImageSourceCreateWithURL(url as CFURL, nil)
        case .data(let data):
            source = CGImageSourceCreateWithData(data as CFData, nil)
        }
        guard let source, let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw RenderError.cannotLoadImage(source: image.source, reason: "not an image ImageIO can read")
        }
        return cgImage
    }
}
