import CoreGraphics
import CoreImage
import Foundation
import VectorScript

extension Renderer {
    static let maximumFilterPixels = 64 * 1024 * 1024
    // PDF has no pixels, so filtered elements are drawn at this many pixels per point.
    static let vectorFilterResolution = 4.0

    // Draws the element's content offscreen over the visible area (plus room for blurs and shadows to spread),
    // runs the filters with Core Image, and draws the result back in base space.
    func drawFiltered(_ element: Element, filters: [Filter], in context: CGContext) throws {
        let ctm = context.ctm
        let visible = context.boundingBoxOfClipPath
        guard !visible.isNull, !visible.isInfinite, !visible.isEmpty else {
            return
        }
        let resolution = context.bitsPerPixel > 0 ? 1 : Self.vectorFilterResolution
        // Pixels per user unit, for turning blur radii and offsets into pixels.
        let scale = abs(ctm.a * ctm.d - ctm.b * ctm.c).squareRoot() * resolution
        let reach = filters.map(\.reach).reduce(0, +) * scale / resolution
        let baseRect = visible.applying(ctm).insetBy(dx: -reach, dy: -reach).integral
        let width = max(1, Int(baseRect.width * resolution))
        let height = max(1, Int(baseRect.height * resolution))
        guard width * height <= Self.maximumFilterPixels else {
            throw RenderError.filterTooLarge(width: width, height: height)
        }
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB), let offscreen = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw RenderError.cannotCreateContext
        }
        offscreen.scaleBy(x: resolution, y: resolution)
        offscreen.translateBy(x: -baseRect.minX, y: -baseRect.minY)
        offscreen.concatenate(ctm)
        try drawContent(of: element, in: offscreen)
        guard let source = offscreen.makeImage() else {
            throw RenderError.cannotCreateImage
        }
        let extent = CGRect(x: 0, y: 0, width: width, height: height)
        var image = CIImage(cgImage: source)
        for filter in filters {
            image = Self.apply(filter, to: image, scale: scale).cropped(to: extent)
        }
        // CSS filters work on sRGB values, so Core Image works in sRGB too.
        let ciContext = CIContext(options: [.workingColorSpace: colorSpace, .outputColorSpace: colorSpace])
        guard let result = ciContext.createCGImage(image, from: extent) else {
            throw RenderError.cannotCreateImage
        }
        context.saveGState()
        context.concatenate(ctm.inverted())
        context.draw(result, in: baseRect)
        context.restoreGState()
    }

    // `scale` is pixels per user unit. Core Image's y axis points up, like base space.
    private static func apply(_ filter: Filter, to image: CIImage, scale: Double) -> CIImage {
        switch filter {
        case .blur(let radius):
            return blur(image, radius: radius * scale)
        case .dropShadow(let offset, let blur, let color):
            // The image's alpha, painted in the shadow color, blurred and moved.
            let shadow = image.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: color.alpha),
                "inputBiasVector": CIVector(x: color.red, y: color.green, z: color.blue, w: 0),
            ])
            let moved = Self.blur(shadow, radius: blur * scale).transformed(by: CGAffineTransform(translationX: offset.x * scale, y: -offset.y * scale))
            return image.composited(over: moved)
        case .grayscale(let amount):
            return image.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 1 - amount])
        case .saturate(let amount):
            return image.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: amount])
        case .sepia(let amount):
            return image.applyingFilter("CISepiaTone", parameters: [kCIInputIntensityKey: amount])
        case .brightness(let amount):
            return colorMatrix(image, multiply: amount, add: 0)
        case .contrast(let amount):
            return colorMatrix(image, multiply: amount, add: 0.5 * (1 - amount))
        case .invert(let amount):
            return colorMatrix(image, multiply: 1 - 2 * amount, add: amount)
        case .hueRotate(let degrees):
            return image.applyingFilter("CIHueAdjust", parameters: [kCIInputAngleKey: degrees * .pi / 180])
        }
    }

    private static func blur(_ image: CIImage, radius: Double) -> CIImage {
        guard radius > 0 else {
            return image
        }
        return image.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: radius])
    }

    // Each color channel becomes channel * multiply + add, on unpremultiplied values; alpha is kept.
    private static func colorMatrix(_ image: CIImage, multiply: Double, add: Double) -> CIImage {
        image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: multiply, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: multiply, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: multiply, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBiasVector": CIVector(x: add, y: add, z: add, w: 0),
        ])
    }
}
