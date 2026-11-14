import Foundation
import Observation
import SwiftUI
import UniformTypeIdentifiers

public extension UTType {
    // Declared as an imported type in the app's Info.plist.
    static var json5: UTType {
        UTType(importedAs: "org.json5.json5")
    }
}

// A VectorScript file, held as its JSON5 source text so comments and formatting survive editing.
@Observable
public final class VectorScriptDocument: Document {
    public static let readableContentTypes: [UTType] = [.json5, .json]
    public static let writableContentTypes: [UTType] = [.json5, .json]

    public var source: String

    public init(source: String = VectorScriptDocument.starterSource) {
        self.source = source
    }

    public static let starterSource = """
    {
      $schema: "https://github.com/schwa/VectorScript/vectorscript.schema.json",
      size: [256, 256],
      background: "#203040",
      elements: [
        { circle: [128, 128, 80], fill: { radialGradient: { focus: [0.35, 0.35], stops: [[0, "#ffe9a8"], [1, "#f0a830"]] } } },
        { text: "VectorScript", at: [128, 236], anchor: "middle", font: "Helvetica-Bold", fontSize: 22, fill: "#fff" }
      ]
    }

    """

    public func reader(configuration: sending ReadConfiguration) -> sending FileWrapperDocumentReader<String> {
        FileWrapperDocumentReader(configuration) { fileWrapper in
            guard let data = fileWrapper.regularFileContents, let text = String(data: data, encoding: .utf8) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            return text
        }
    }

    @MainActor
    public func apply(snapshot: sending String, previous: sending String?) async throws {
        source = snapshot
    }

    public func writer(configuration: sending WriteConfiguration) -> sending FileWrapperDocumentWriter<String> {
        FileWrapperDocumentWriter(configuration) { snapshot, _ in
            FileWrapper(regularFileWithContents: Data(snapshot.utf8))
        }
    }

    @MainActor
    public func snapshot(contentType: UTType) async throws -> sending String {
        source
    }
}
