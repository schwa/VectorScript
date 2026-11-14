import CoreGraphics
import Foundation
import Observation
import VectorScript
import VectorScriptRender

@MainActor
@Observable
public final class ViewerModel {
    public private(set) var url: URL?
    // The JSON5 being edited. Every change re-parses and re-renders.
    public var source: String = "" {
        didSet {
            guard source != oldValue else {
                return
            }
            isDirty = source != savedSource
            parse()
        }
    }
    public private(set) var isDirty = false
    public private(set) var document: Document?
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

    private var savedSource = ""
    private var modificationDate: Date?
    private var watchTask: Task<Void, Never>?
    private var isAccessingSecurityScope = false

    public init() {}

    public func open(_ url: URL) {
        close()
        isAccessingSecurityScope = url.startAccessingSecurityScopedResource()
        self.url = url
        reload()
        watch()
    }

    public func close() {
        watchTask?.cancel()
        watchTask = nil
        if isAccessingSecurityScope {
            url?.stopAccessingSecurityScopedResource()
            isAccessingSecurityScope = false
        }
        url = nil
        savedSource = ""
        source = ""
        isDirty = false
        document = nil
        image = nil
        errorMessage = nil
    }

    // Reads the file again, dropping unsaved edits.
    public func reload() {
        guard let url else {
            return
        }
        modificationDate = Self.modificationDate(of: url)
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            savedSource = text
            source = text
            isDirty = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func save() throws {
        guard let url else {
            return
        }
        try Data(source.utf8).write(to: url)
        savedSource = source
        isDirty = false
        modificationDate = Self.modificationDate(of: url)
    }

    private func parse() {
        do {
            document = try Document(json: Data(source.utf8))
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

    // Polls the file so saves from other editors show up, including editors that replace the file. Unsaved edits
    // here win: the file is only reloaded when there are none.
    private func watch() {
        watchTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard let self, let url = self.url else {
                    return
                }
                let date = Self.modificationDate(of: url)
                if date != self.modificationDate {
                    if self.isDirty {
                        self.modificationDate = date
                    } else {
                        self.reload()
                    }
                }
            }
        }
    }

    private static func modificationDate(of url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }
}
