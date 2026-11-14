import SwiftUI
import VectorScript

public struct DocumentView: View {
    @Bindable var document: VectorScriptDocument
    @State private var preview = PreviewModel()
    @SceneStorage("showsSource") private var showsSource = true
    @Environment(\.displayScale) private var displayScale
    @Environment(\.undoManager) private var undoManager

    public init(document: VectorScriptDocument) {
        self.document = document
    }

    public var body: some View {
        content
            .frame(minWidth: 480, minHeight: 320)
            .toolbar {
                ToolbarItemGroup {
                    Toggle("Source", systemImage: "curlybraces", isOn: $showsSource)
                    ZoomControl(zoom: $preview.zoom)
                }
            }
            .onChange(of: document.source, initial: true) {
                preview.update(source: document.source, baseURL: document.fileURL)
            }
            .onChange(of: document.fileURL) {
                preview.update(source: document.source, baseURL: document.fileURL)
            }
            // SwiftUI detects unsaved changes, and so autosaves, through the undo stack.
            .onChange(of: document.source) { oldValue, _ in
                undoManager?.registerUndo(withTarget: document) { document in
                    document.source = oldValue
                }
            }
            .onChange(of: displayScale, initial: true) {
                preview.displayScale = displayScale
            }
    }

    @ViewBuilder
    private var content: some View {
        if showsSource {
            SplitLayout {
                SourceEditor(source: $document.source, errorMessage: preview.errorMessage)
                    .frame(minWidth: 240, idealWidth: 420)
                PlayablePreview(model: preview, displayScale: displayScale)
                    .frame(minWidth: 240)
            }
        } else {
            PlayablePreview(model: preview, displayScale: displayScale)
                .safeAreaInset(edge: .bottom) {
                    if let message = preview.errorMessage {
                        ErrorBanner(message: message)
                    }
                }
        }
    }
}

// HSplitView on macOS; a fixed side-by-side layout elsewhere.
struct SplitLayout<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        #if os(macOS)
        HSplitView {
            content
        }
        #else
        HStack(spacing: 0) {
            content
        }
        #endif
    }
}

struct SourceEditor: View {
    @Binding var source: String
    let errorMessage: String?
    @State private var text = AttributedString()

    var body: some View {
        TextEditor(text: $text)
            .onChange(of: source, initial: true) {
                // Undo, revert and file reloads change the source from outside.
                if String(text.characters) != source {
                    text = JSON5Highlighter.highlighted(source)
                }
            }
            .onChange(of: text) {
                let edited = String(text.characters)
                if edited != source {
                    source = edited
                }
                var recolored = text
                JSON5Highlighter.highlight(&recolored)
                if recolored != text {
                    text = recolored
                }
            }
            .font(.body.monospaced())
            .autocorrectionDisabled()
            .scrollContentBackground(.hidden)
            .padding(4)
            .background(.background)
            .safeAreaInset(edge: .bottom) {
                if let errorMessage {
                    ErrorBanner(message: errorMessage)
                }
            }
    }
}

// The preview, with play, pause and a time slider when the document is animated.
struct PlayablePreview: View {
    @Bindable var model: PreviewModel
    let displayScale: Double

    var body: some View {
        Preview(image: model.image, displayScale: displayScale)
            .safeAreaInset(edge: .bottom) {
                if let animation = model.animation {
                    PlaybackBar(model: model, animation: animation)
                }
            }
    }
}

struct PlaybackBar: View {
    @Bindable var model: PreviewModel
    let animation: DocumentAnimation

    var body: some View {
        HStack {
            Button(model.isPlaying ? "Pause" : "Play", systemImage: model.isPlaying ? "pause.fill" : "play.fill") {
                if model.isPlaying {
                    model.pause()
                } else {
                    model.play()
                }
            }
            .labelStyle(.iconOnly)
            Slider(value: $model.time, in: 0...animation.duration) { editing in
                if editing {
                    model.pause()
                }
            }
            Text("\(model.time.formatted(.number.precision(.fractionLength(2)))) / \(animation.duration.formatted(.number.precision(.fractionLength(2)))) s")
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(.bar)
        // Drives playback at the document's frame rate; paused when not playing.
        .background {
            TimelineView(.animation(minimumInterval: 1 / animation.framesPerSecond, paused: !model.isPlaying)) { timeline in
                Color.clear
                    .onChange(of: timeline.date) {
                        model.advance(to: timeline.date)
                    }
            }
        }
    }
}

struct Preview: View {
    let image: CGImage?
    let displayScale: Double

    var body: some View {
        if let image {
            ScrollView([.horizontal, .vertical]) {
                Image(decorative: image, scale: displayScale)
                    .background {
                        Checkerboard()
                    }
                    .shadow(radius: 4)
                    .padding(24)
            }
            .defaultScrollAnchor(.center)
        } else {
            Color.clear
        }
    }
}

struct ZoomControl: View {
    @Binding var zoom: Double

    static let levels: [Double] = [0.25, 0.5, 1, 2, 4, 8]

    var body: some View {
        Menu {
            ForEach(Self.levels, id: \.self) { level in
                Button(level.formatted(.percent)) {
                    zoom = level
                }
            }
        } label: {
            Label(zoom.formatted(.percent), systemImage: "plus.magnifyingglass")
        }
    }
}

struct ErrorBanner: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.callout.monospaced())
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(.red.opacity(0.15), in: .rect(cornerRadius: 8))
            .padding(8)
    }
}

// Shows where the drawing is transparent.
struct Checkerboard: View {
    var body: some View {
        Canvas { context, size in
            let cell = 8.0
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            for row in 0..<Int((size.height / cell).rounded(.up)) {
                for column in 0..<Int((size.width / cell).rounded(.up)) where (row + column).isMultiple(of: 2) {
                    context.fill(Path(CGRect(x: Double(column) * cell, y: Double(row) * cell, width: cell, height: cell)), with: .color(Color(white: 0.85)))
                }
            }
        }
    }
}

#Preview {
    DocumentView(document: VectorScriptDocument())
}
