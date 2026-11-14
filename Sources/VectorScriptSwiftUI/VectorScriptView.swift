import SwiftUI
import VectorScript
import VectorScriptRender

// Shows a document, drawn as vectors at whatever size the view gets. Its ideal size is the document's size.
// An animated document plays, unless a fixed `time` is given.
public struct VectorScriptView: View {
    private enum Content {
        case still(Result<Renderer, any Error>)
        case animated(DocumentSource, DocumentAnimation)
        case failed(any Error)
    }

    private let content: Content
    private let size: VectorScript.Size
    private let time: Double?
    @State private var start = Date()

    private static let errorSize = VectorScript.Size(width: 200, height: 100)

    private init(content: Content, size: VectorScript.Size, time: Double?) {
        self.content = content
        self.size = size
        self.time = time
    }

    public init(_ document: VectorScript.Document) {
        self.init(content: .still(Result { try Renderer(document: document) }), size: document.size, time: nil)
    }

    // Plays the source's animation, or shows `time` when set. A still source shows as it is.
    public init(_ source: DocumentSource, time: Double? = nil) {
        do {
            let first = try source.document(at: time ?? 0)
            if let animation = source.animation {
                self.init(content: .animated(source, animation), size: first.size, time: time)
            } else {
                self.init(content: .still(Result { try Renderer(document: first) }), size: first.size, time: time)
            }
        } catch {
            self.init(content: .failed(error), size: Self.errorSize, time: time)
        }
    }

    // Reads the file now; read errors show in the view like render errors.
    public init(contentsOf url: URL, time: Double? = nil) {
        do {
            self.init(try DocumentSource(contentsOf: url), time: time)
        } catch {
            self.init(content: .failed(error), size: Self.errorSize, time: time)
        }
    }

    public var body: some View {
        Group {
            switch content {
            case .still(let renderer):
                canvas { try renderer.get() }
            case .failed(let error):
                canvas { throw error }
            case .animated(let source, let animation):
                if let time {
                    canvas { try Renderer(document: source.document(at: time)) }
                } else {
                    TimelineView(.animation(minimumInterval: 1 / animation.framesPerSecond)) { timeline in
                        let elapsed = timeline.date.timeIntervalSince(start)
                        canvas { try Renderer(document: source.document(at: animation.time(atElapsed: elapsed))) }
                    }
                }
            }
        }
        .frame(idealWidth: size.width, idealHeight: size.height)
    }

    private func canvas(_ makeRenderer: @escaping () throws -> Renderer) -> some View {
        Canvas { context, canvasSize in
            let bounds = CGRect(origin: .zero, size: canvasSize)
            var failure: (any Error)?
            do {
                let renderer = try makeRenderer()
                context.withCGContext { cgContext in
                    do {
                        try renderer.draw(in: cgContext, bounds: bounds)
                    } catch {
                        failure = error
                    }
                }
            } catch {
                failure = error
            }
            if let failure {
                Self.drawError(failure, in: &context, bounds: bounds)
            }
        }
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
