import CoreGraphics
import Foundation
import Observation
import VectorScript
import VectorScriptRender

// Parses and renders a document's source for the preview.
@MainActor
@Observable
public final class PreviewModel {
    public private(set) var document: VectorScript.Document?
    public private(set) var image: CGImage?
    public private(set) var errorMessage: String?
    public var zoom: Double = 1 {
        didSet {
            render()
        }
    }
    public var displayScale: Double = 2 {
        didSet {
            render()
        }
    }

    private var source: String?

    public init() {}

    public func update(source: String) {
        guard source != self.source else {
            return
        }
        self.source = source
        do {
            document = try VectorScript.Document(json: Data(source.utf8))
            errorMessage = nil
            render()
        } catch {
            // Keep the last good image on screen while the source is broken.
            errorMessage = "\(error)"
        }
    }

    private func render() {
        guard let document else {
            return
        }
        do {
            image = try Renderer(document: document).cgImage(scale: zoom * displayScale)
        } catch {
            errorMessage = "\(error)"
        }
    }
}
