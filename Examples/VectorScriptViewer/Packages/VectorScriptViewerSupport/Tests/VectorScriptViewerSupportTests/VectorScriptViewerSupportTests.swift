import Foundation
import Testing
import VectorScript
@testable import VectorScriptViewerSupport

@MainActor
struct PreviewModelTests {
    @Test
    func `a source renders`() {
        let model = PreviewModel()
        model.displayScale = 1
        model.update(source: "{ size: [20, 10], elements: [{ circle: [5, 5, 4] }] }")
        #expect(model.image?.width == 20)
        #expect(model.errorMessage == nil)
        model.zoom = 2
        #expect(model.image?.width == 40)
    }

    @Test
    func `a broken source keeps the last image and shows the error`() {
        let model = PreviewModel()
        model.update(source: "{ size: [8, 8], elements: [] }")
        model.update(source: "{ size: [8, 8], elements: [{ circle: [1, 1, 1], fil: 'red' }] }")
        #expect(model.image != nil)
        #expect(model.errorMessage == "elements[0]: unknown key 'fil'")
        model.update(source: "{ size: [8, 8], elements: [] }")
        #expect(model.errorMessage == nil)
    }
}

struct VectorScriptDocumentTests {
    @Test
    func `the starter document is valid`() throws {
        _ = try VectorScript.Document(json: Data(VectorScriptDocument.starterSource.utf8)).resolved()
    }
}
