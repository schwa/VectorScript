import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import VectorScript

public enum OutputFormat: String, Sendable, CaseIterable {
    case png, jpeg, gif, pdf

    // The format for a file extension, if it is one this package writes.
    public init?(pathExtension: String) {
        switch pathExtension.lowercased() {
        case "png": self = .png
        case "jpg", "jpeg": self = .jpeg
        case "gif": self = .gif
        case "pdf": self = .pdf
        default: return nil
        }
    }

    public var pathExtension: String {
        self == .jpeg ? "jpg" : rawValue
    }
}

public extension Renderer {
    func data(format: OutputFormat, size: Size? = nil, scale: Double = 1) throws -> Data {
        switch format {
        case .pdf:
            return try pdfData(size: size)
        case .png, .jpeg, .gif:
            let image = try cgImage(size: size, scale: scale)
            let data = NSMutableData()
            let type: UTType = switch format {
            case .jpeg: .jpeg
            case .gif: .gif
            default: .png
            }
            guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, type.identifier as CFString, 1, nil) else {
                throw RenderError.cannotCreateImage
            }
            CGImageDestinationAddImage(destination, image, nil)
            guard CGImageDestinationFinalize(destination) else {
                throw RenderError.cannotCreateImage
            }
            return data as Data
        }
    }

    func write(to url: URL, format: OutputFormat, size: Size? = nil, scale: Double = 1) throws {
        let data = try data(format: format, size: size, scale: scale)
        do {
            try data.write(to: url)
        } catch {
            throw RenderError.cannotWrite(url)
        }
    }
}
