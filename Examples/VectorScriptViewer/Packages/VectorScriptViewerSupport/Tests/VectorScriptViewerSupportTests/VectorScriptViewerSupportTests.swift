import Foundation
import Testing
@testable import VectorScriptViewerSupport

@MainActor
struct ViewerModelTests {
    func file(_ contents: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "ViewerModelTests-\(UUID()).json5")
        try Data(contents.utf8).write(to: url)
        return url
    }

    @Test
    func `opening a document renders it`() throws {
        let model = ViewerModel()
        model.displayScale = 1
        model.open(try file("{ size: [20, 10], elements: [{ circle: [5, 5, 4] }] }"))
        #expect(model.image?.width == 20)
        #expect(model.errorMessage == nil)
        #expect(!model.isDirty)
        model.zoom = 2
        #expect(model.image?.width == 40)
        model.close()
    }

    @Test
    func `editing re-renders and marks the document dirty`() throws {
        let model = ViewerModel()
        model.displayScale = 1
        model.open(try file("{ size: [8, 8], elements: [] }"))
        model.source = "{ size: [16, 8], elements: [] }"
        #expect(model.isDirty)
        #expect(model.image?.width == 16)
        model.close()
    }

    @Test
    func `a broken edit keeps the last image and shows the error`() throws {
        let model = ViewerModel()
        model.open(try file("{ size: [8, 8], elements: [] }"))
        model.source = "{ size: [8, 8], elements: [{ circle: [1, 1, 1], fil: 'red' }] }"
        #expect(model.image != nil)
        #expect(model.errorMessage == "elements[0]: unknown key 'fil'")
        model.close()
    }

    @Test
    func `save writes the source and clears dirty`() throws {
        let model = ViewerModel()
        let url = try file("{ size: [8, 8], elements: [] }")
        model.open(url)
        let edited = "{ size: [9, 9], elements: [] }"
        model.source = edited
        try model.save()
        #expect(!model.isDirty)
        #expect(try String(contentsOf: url, encoding: .utf8) == edited)
        model.close()
    }

    @Test
    func `reload drops unsaved edits`() throws {
        let model = ViewerModel()
        let original = "{ size: [8, 8], elements: [] }"
        model.open(try file(original))
        model.source = "{ size: [9, 9], elements: [] }"
        model.reload()
        #expect(model.source == original)
        #expect(!model.isDirty)
        model.close()
    }

    @Test
    func `undoing an edit by hand is not dirty`() throws {
        let model = ViewerModel()
        let original = "{ size: [8, 8], elements: [] }"
        model.open(try file(original))
        model.source = original + " "
        model.source = original
        #expect(!model.isDirty)
        model.close()
    }
}
