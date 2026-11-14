import SwiftUI
import VectorScriptViewerSupport

@main
struct VectorScriptViewerApp: App {
    var body: some Scene {
        DocumentGroup { document in
            DocumentView(document: document)
        } makeDocument: { configuration, _ in
            VectorScriptDocument(configuration: configuration)
        }
    }
}
