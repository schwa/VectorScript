import SwiftUI
import VectorScriptViewerSupport

@main
struct VectorScriptViewerApp: App {
    var body: some Scene {
        DocumentGroup { document in
            DocumentView(document: document)
        } makeDocument: { _, _ in
            VectorScriptDocument()
        }
    }
}
