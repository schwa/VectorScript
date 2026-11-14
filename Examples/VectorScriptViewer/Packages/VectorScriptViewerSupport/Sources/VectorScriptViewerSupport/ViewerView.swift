import SwiftUI
import UniformTypeIdentifiers

public struct ViewerView: View {
    @State private var model = ViewerModel()
    @State private var isImporting = false
    @State private var isDropTargeted = false
    @State private var showsSource = true
    @State private var saveError: String?
    @Environment(\.displayScale) private var displayScale

    static let contentTypes: [UTType] = [.json, UTType(filenameExtension: "json5") ?? .json]

    public init() {}

    public var body: some View {
        content
            .frame(minWidth: 480, minHeight: 320)
            .overlay {
                if isDropTargeted {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.tint, lineWidth: 3)
                        .padding(4)
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItemGroup {
                    Button("Open…", systemImage: "folder") {
                        isImporting = true
                    }
                    .keyboardShortcut("o")
                    Button("Save", systemImage: "square.and.arrow.down") {
                        save()
                    }
                    .keyboardShortcut("s")
                    .disabled(!model.isDirty)
                    Button("Revert", systemImage: "arrow.uturn.backward") {
                        model.reload()
                    }
                    .disabled(!model.isDirty)
                    Toggle("Source", systemImage: "curlybraces", isOn: $showsSource)
                        .disabled(model.url == nil)
                    ZoomControl(zoom: $model.zoom)
                }
            }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: Self.contentTypes) { result in
                if case .success(let url) = result {
                    model.open(url)
                }
            }
            .dropDestination(for: URL.self) { urls, _ in
                guard let url = urls.first else {
                    return false
                }
                model.open(url)
                return true
            } isTargeted: {
                isDropTargeted = $0
            }
            .onChange(of: displayScale, initial: true) {
                model.displayScale = displayScale
            }
            .alert("Cannot Save", isPresented: .constant(saveError != nil)) {
                Button("OK") {
                    saveError = nil
                }
            } message: {
                Text(saveError ?? "")
            }
    }

    private var title: String {
        guard let url = model.url else {
            return "VectorScript Viewer"
        }
        return url.lastPathComponent + (model.isDirty ? " — Edited" : "")
    }

    private func save() {
        do {
            try model.save()
        } catch {
            saveError = error.localizedDescription
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.url == nil {
            ContentUnavailableView {
                Label("No Document", systemImage: "scribble.variable")
            } description: {
                Text("Open or drop a VectorScript .json or .json5 file. Edit it here or in any editor; the preview follows.")
            } actions: {
                Button("Open…") {
                    isImporting = true
                }
            }
        } else if showsSource {
            SplitLayout {
                SourceEditor(source: $model.source, errorMessage: model.errorMessage)
                    .frame(minWidth: 240, idealWidth: 420)
                Preview(image: model.image, displayScale: displayScale)
                    .frame(minWidth: 240)
            }
        } else {
            Preview(image: model.image, displayScale: displayScale)
                .safeAreaInset(edge: .bottom) {
                    if let message = model.errorMessage {
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

    var body: some View {
        TextEditor(text: $source)
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
    ViewerView()
}
