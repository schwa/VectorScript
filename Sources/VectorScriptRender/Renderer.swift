import CoreGraphics
import CoreText
import Foundation
import VectorScript

public enum RenderError: Error, Equatable, CustomStringConvertible {
    case unknownFont(String)
    case cannotCreateContext
    case cannotCreateImage
    case cannotWrite(URL)
    case tooManyPatternTiles(Int)
    case maskTooLarge(width: Int, height: Int)
    case filterTooLarge(width: Int, height: Int)
    case cannotLoadImage(source: String, reason: String)
    case cannotLoadFont(file: String, reason: String)

    public var description: String {
        switch self {
        case .unknownFont(let name): "unknown font '\(name)'"
        case .cannotCreateContext: "cannot create a drawing context"
        case .cannotCreateImage: "cannot create an image"
        case .cannotWrite(let url): "cannot write \(url.path)"
        case .cannotLoadImage(let source, let reason): "cannot load image '\(source.count > 60 ? source.prefix(60) + "…" : source)': \(reason)"
        case .cannotLoadFont(let file, let reason): "cannot load font file '\(file)': \(reason)"
        case .filterTooLarge(let width, let height): "a filter needs a \(width) x \(height) pixel image, which is too big"
        case .maskTooLarge(let width, let height): "a mask needs a \(width) x \(height) pixel image, which is too big"
        case .tooManyPatternTiles(let count): "a pattern needs \(count) tiles here (the limit is \(Renderer.maximumPatternTiles)); make its tile bigger"
        }
    }
}

// Draws resolved documents with CoreGraphics. Unresolved documents are resolved first.
public struct Renderer: Sendable {
    public var document: Document

    public init(document: Document) throws {
        self.document = document.isResolved ? document : try document.resolved()
    }

    // Pixel size for an output `size` (the document size when nil) at `scale`.
    public func pixelSize(size: Size? = nil, scale: Double = 1) -> (width: Int, height: Int) {
        let size = size ?? document.size
        return (max(1, Int((size.width * scale).rounded())), max(1, Int((size.height * scale).rounded())))
    }

    // Draws into `context`, whose user space has y down and covers `bounds`.
    public func draw(in context: CGContext, bounds: CGRect) throws {
        let viewBox = document.viewBox ?? Rect(x: 0, y: 0, width: document.size.width, height: document.size.height)
        context.saveGState()
        defer {
            context.restoreGState()
        }
        if let background = document.background {
            context.setFillColor(background.cgColor)
            context.fill(bounds)
        }
        // Background fills the whole canvas; content stays inside it even when slice overflows.
        context.clip(to: bounds)
        let target = Rect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: bounds.height)
        context.concatenate(document.preserveAspectRatio.matrix(mapping: viewBox, onto: target).cgAffineTransform)
        for element in document.elements {
            try draw(element, in: context)
        }
    }

    public func cgImage(size: Size? = nil, scale: Double = 1) throws -> CGImage {
        let pixels = pixelSize(size: size, scale: scale)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB), let context = CGContext(data: nil, width: pixels.width, height: pixels.height, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw RenderError.cannotCreateContext
        }
        // Bitmap contexts have y up; flip so the document's y-down space lands the right way round.
        context.translateBy(x: 0, y: CGFloat(pixels.height))
        context.scaleBy(x: 1, y: -1)
        try draw(in: context, bounds: CGRect(x: 0, y: 0, width: pixels.width, height: pixels.height))
        guard let image = context.makeImage() else {
            throw RenderError.cannotCreateImage
        }
        return image
    }

    // A one-page vector PDF.
    public func pdfData(size: Size? = nil) throws -> Data {
        let size = size ?? document.size
        var mediaBox = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData), let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw RenderError.cannotCreateContext
        }
        context.beginPDFPage(nil)
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
        try draw(in: context, bounds: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        context.endPDFPage()
        context.closePDF()
        return data as Data
    }

    func draw(_ element: Element, in context: CGContext) throws {
        context.saveGState()
        defer {
            context.restoreGState()
        }
        if let transform = element.transform {
            context.concatenate(transform.matrix.cgAffineTransform)
        }
        if let clip = element.clip {
            context.addPath(clip.shape.cgPath)
            context.clip(using: clip.fillRule.cgFillRule)
        }
        if let mask = element.mask {
            try apply(mask, in: context)
        }
        let opacity = element.opacity ?? 1
        let blendMode = element.blendMode ?? .normal
        // The element draws into a layer, which is composited once with the alpha and blend mode set here.
        let layered = opacity < 1 || blendMode != .normal
        if layered {
            context.setAlpha(opacity)
            context.setBlendMode(blendMode.cgBlendMode)
            context.beginTransparencyLayer(auxiliaryInfo: nil)
            context.setBlendMode(.normal)
        }
        defer {
            if layered {
                context.endTransparencyLayer()
            }
        }
        if let filter = element.filter, !filter.filters.isEmpty {
            try drawFiltered(element, filters: filter.filters, in: context)
        } else {
            try drawContent(of: element, in: context)
        }
    }

    // The element's own drawing, without its transform, clip, mask, opacity, blend mode or filter.
    func drawContent(of element: Element, in context: CGContext) throws {
        switch element.content {
        case .shape(let shape):
            try paint(shape.cgPath, style: element.style, in: context)
            try drawMarkers(on: shape, style: element.style, in: context)
        case .text(let text):
            try paint(try text.cgPath(style: element.style, baseURL: document.baseURL), style: element.style, in: context)
        case .group(let children):
            for child in children {
                try draw(child, in: context)
            }
        case .image(let image):
            try draw(image, in: context)
        case .use:
            preconditionFailure("Renderer only draws resolved documents")
        }
    }

    private func paint(_ path: CGPath, style: Style, in context: CGContext) throws {
        let fillRule = (style.fillRule ?? .nonzero).cgFillRule
        if let fill = style.fill {
            try paint(fill, area: path, bounds: path.boundingBoxOfPath, fillRule: fillRule, in: context)
        }
        guard let stroke = style.stroke, stroke != .none, let width = style.strokeWidth, width > 0 else {
            return
        }
        context.saveGState()
        context.setLineWidth(width)
        context.setLineCap(style.strokeCap?.cgLineCap ?? .butt)
        context.setLineJoin(style.strokeJoin?.cgLineJoin ?? .miter)
        context.setMiterLimit(style.strokeMiterLimit ?? 4)
        context.setLineDash(phase: style.strokeDashOffset ?? 0, lengths: (style.strokeDash ?? []).map { CGFloat($0) })
        context.addPath(path)
        context.replacePathWithStrokedPath()
        guard let outline = context.path else {
            context.restoreGState()
            return
        }
        context.beginPath()
        // Gradients on strokes map onto the shape's bounding box, as in SVG.
        try paint(stroke, area: outline, bounds: path.boundingBoxOfPath, fillRule: .winding, in: context)
        context.restoreGState()
    }

    private func paint(_ paint: Paint, area: CGPath, bounds: CGRect, fillRule: CGPathFillRule, in context: CGContext) throws {
        switch paint {
        case .none, .reference:
            return
        case .color(let color):
            context.setFillColor(color.cgColor)
            context.addPath(area)
            context.fillPath(using: fillRule)
        case .linearGradient(let gradient):
            guard let cgGradient = Self.cgGradient(gradient.stops) else {
                return
            }
            context.saveGState()
            context.addPath(area)
            context.clip(using: fillRule)
            Self.applyUnits(gradient.units, bounds: bounds, in: context)
            context.drawLinearGradient(cgGradient, start: gradient.from.cgPoint, end: gradient.to.cgPoint, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            context.restoreGState()
        case .radialGradient(let gradient):
            guard let cgGradient = Self.cgGradient(gradient.stops) else {
                return
            }
            context.saveGState()
            context.addPath(area)
            context.clip(using: fillRule)
            Self.applyUnits(gradient.units, bounds: bounds, in: context)
            context.drawRadialGradient(cgGradient, startCenter: (gradient.focus ?? gradient.center).cgPoint, startRadius: 0, endCenter: gradient.center.cgPoint, endRadius: gradient.radius, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            context.restoreGState()
        case .pattern(let pattern):
            try fill(area, fillRule: fillRule, with: pattern, in: context)
        }
    }

    private static func applyUnits(_ units: GradientUnits, bounds: CGRect, in context: CGContext) {
        guard units == .boundingBox, bounds.width > 0, bounds.height > 0 else {
            return
        }
        context.translateBy(x: bounds.minX, y: bounds.minY)
        context.scaleBy(x: bounds.width, y: bounds.height)
    }

    private static func cgGradient(_ stops: [GradientStop]) -> CGGradient? {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            return nil
        }
        // SVG clamps each offset to at least the previous one.
        var offsets: [CGFloat] = []
        for stop in stops {
            offsets.append(max(stop.offset, offsets.last ?? 0))
        }
        return CGGradient(colorsSpace: colorSpace, colors: stops.map(\.color.cgColor) as CFArray, locations: offsets)
    }
}
