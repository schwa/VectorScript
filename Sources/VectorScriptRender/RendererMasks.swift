import CoreGraphics
import Foundation
import VectorScript

extension Renderer {
    static let maximumMaskPixels = 64 * 1024 * 1024
    // PDF has no pixels, so its masks are drawn at this many pixels per point.
    static let vectorMaskResolution = 4.0

    // Clips the context to the mask: renders the mask's elements offscreen over the visible area and turns them
    // into a grayscale image mask in the context's base space.
    func apply(_ mask: Mask, in context: CGContext) throws {
        let ctm = context.ctm
        let visible = context.boundingBoxOfClipPath
        guard !visible.isNull, !visible.isInfinite, !visible.isEmpty else {
            return
        }
        let baseRect = visible.applying(ctm).integral
        let resolution = context.bitsPerPixel > 0 ? 1 : Self.vectorMaskResolution
        let width = max(1, Int(baseRect.width * resolution))
        let height = max(1, Int(baseRect.height * resolution))
        guard width * height <= Self.maximumMaskPixels else {
            throw RenderError.maskTooLarge(width: width, height: height)
        }
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB), let maskContext = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw RenderError.cannotCreateContext
        }
        maskContext.scaleBy(x: resolution, y: resolution)
        maskContext.translateBy(x: -baseRect.minX, y: -baseRect.minY)
        maskContext.concatenate(ctm)
        for element in mask.elements {
            try draw(element, in: maskContext)
        }
        let image = try Self.coverageImage(of: maskContext, width: width, height: height, mode: mask.mode)
        // clip(to:mask:) takes its rectangle in user space; step out to base space so the image lines up with pixels.
        context.concatenate(ctm.inverted())
        context.clip(to: baseRect, mask: image)
        context.concatenate(ctm)
    }

    // One gray byte per pixel: the mask's coverage. Luminance uses Rec. 709 weights on sRGB values, times alpha.
    private static func coverageImage(of context: CGContext, width: Int, height: Int, mode: MaskMode) throws -> CGImage {
        guard let data = context.data else {
            throw RenderError.cannotCreateImage
        }
        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        var gray = [UInt8](repeating: 0, count: width * height)
        for index in 0..<(width * height) {
            let red = Double(pixels[index * 4])
            let green = Double(pixels[index * 4 + 1])
            let blue = Double(pixels[index * 4 + 2])
            let alpha = pixels[index * 4 + 3]
            switch mode {
            case .alpha:
                gray[index] = alpha
            case .luminance:
                // Premultiplied components already carry alpha.
                gray[index] = UInt8(min(255, (0.2126 * red + 0.7152 * green + 0.0722 * blue).rounded()))
            }
        }
        guard let provider = CGDataProvider(data: Data(gray) as CFData), let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue), provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else {
            throw RenderError.cannotCreateImage
        }
        return image
    }
}

