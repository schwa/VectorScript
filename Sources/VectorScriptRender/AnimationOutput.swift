import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import VectorScript

public enum AnimationFormat: String, Sendable, CaseIterable {
    // Animated PNG.
    case png
    case gif

    public init?(pathExtension: String) {
        switch pathExtension.lowercased() {
        case "png", "apng": self = .png
        case "gif": self = .gif
        default: return nil
        }
    }
}

public enum AnimationError: Error, Equatable, CustomStringConvertible {
    case notAnimated

    public var description: String {
        switch self {
        case .notAnimated: "the document has no animation block"
        }
    }
}

public extension DocumentSource {
    // One image per frame, in order, with the time each shows.
    func frames(size: Size? = nil, scale: Double = 1) throws -> [(time: Double, image: CGImage)] {
        guard let animation else {
            throw AnimationError.notAnimated
        }
        return try (0..<animation.frameCount).map { index in
            let time = animation.time(ofFrame: index)
            return (time, try Renderer(document: document(at: time)).cgImage(size: size, scale: scale))
        }
    }

    func writeAnimation(to url: URL, format: AnimationFormat, size: Size? = nil, scale: Double = 1) throws {
        guard let animation else {
            throw AnimationError.notAnimated
        }
        let frames = try frames(size: size, scale: scale)
        let type = format == .png ? UTType.png : UTType.gif
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, frames.count, nil) else {
            throw RenderError.cannotWrite(url)
        }
        let delay = 1 / animation.framesPerSecond
        // A loop count of 0 plays forever.
        let loopCount = animation.loops ? 0 : 1
        let fileProperties: [CFString: Any]
        let frameProperties: [CFString: Any]
        switch format {
        case .png:
            fileProperties = [kCGImagePropertyPNGDictionary: [kCGImagePropertyAPNGLoopCount: loopCount]]
            frameProperties = [kCGImagePropertyPNGDictionary: [kCGImagePropertyAPNGDelayTime: delay, kCGImagePropertyAPNGUnclampedDelayTime: delay]]
        case .gif:
            fileProperties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: loopCount]]
            frameProperties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay, kCGImagePropertyGIFUnclampedDelayTime: delay]]
        }
        CGImageDestinationSetProperties(destination, fileProperties as CFDictionary)
        for frame in frames {
            CGImageDestinationAddImage(destination, frame.image, frameProperties as CFDictionary)
        }
        guard CGImageDestinationFinalize(destination) else {
            throw RenderError.cannotWrite(url)
        }
    }

    // Writes frame-0001.png, frame-0002.png, ... into `directory`, creating it if needed.
    @discardableResult
    func writeFrames(to directory: URL, size: Size? = nil, scale: Double = 1) throws -> [URL] {
        guard let animation else {
            throw AnimationError.notAnimated
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let digits = max(4, String(animation.frameCount).count)
        return try (0..<animation.frameCount).map { index in
            let number = String(index + 1)
            let url = directory.appending(path: "frame-\(String(repeating: "0", count: max(0, digits - number.count)))\(number).png")
            try Renderer(document: document(at: animation.time(ofFrame: index))).write(to: url, format: .png, size: size, scale: scale)
            return url
        }
    }
}
