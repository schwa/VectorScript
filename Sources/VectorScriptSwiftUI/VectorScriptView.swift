import SwiftUI
import VectorScript
import VectorScriptRender

// Shows a document, drawn as vectors at whatever size the view gets. Its ideal size is the document's size.
public struct VectorScriptView: View {
    private let content: Result<Renderer, any Error>
    private let size: VectorScript.Size

    public init(_ document: VectorScript.Document) {
        self.init(size: document.size, content: Result { try Renderer(document: document) })
    }

    private init(size: VectorScript.Size, content: Result<Renderer, any Error>) {
        self.size = size
        self.content = content
    }

    // Reads the file now; read errors show in the view like render errors.
    public init(contentsOf url: URL) {
        do {
            self.init(try VectorScript.Document(contentsOf: url))
        } catch {
            self.init(size: VectorScript.Size(width: 200, height: 100), content: .failure(error))
        }
    }

    public var body: some View {
        Canvas { context, canvasSize in
            let bounds = CGRect(origin: .zero, size: canvasSize)
            switch content {
            case .success(let renderer):
                var failure: (any Error)?
                context.withCGContext { cgContext in
                    do {
                        try renderer.draw(in: cgContext, bounds: bounds)
                    } catch {
                        failure = error
                    }
                }
                if let failure {
                    Self.drawError(failure, in: &context, bounds: bounds)
                }
            case .failure(let error):
                Self.drawError(error, in: &context, bounds: bounds)
            }
        }
        .frame(idealWidth: size.width, idealHeight: size.height)
    }

    // Errors show in the view, since Canvas cannot report them.
    private static func drawError(_ error: any Error, in context: inout GraphicsContext, bounds: CGRect) {
        context.fill(Path(bounds), with: .color(.red.opacity(0.12)))
        context.stroke(Path(bounds.insetBy(dx: 0.5, dy: 0.5)), with: .color(.red), lineWidth: 1)
        context.draw(SwiftUI.Text(verbatim: "\(error)").font(.caption.monospaced()).foregroundStyle(.red), in: bounds.insetBy(dx: 6, dy: 6))
    }
}

#Preview {
    VectorScriptView(VectorScript.Document(size: VectorScript.Size(width: 120, height: 80), background: Color(red: 0.13, green: 0.19, blue: 0.25), elements: [
        Element(.shape(.circle(center: Point(x: 60, y: 40), radius: 28)), style: Style(fill: .color(Color(red: 0.94, green: 0.66, blue: 0.19)))),
    ]))
}
