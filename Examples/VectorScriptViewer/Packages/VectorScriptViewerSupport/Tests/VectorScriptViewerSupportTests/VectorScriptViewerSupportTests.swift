import Foundation
import Testing
import VectorScript
import VectorScriptRender
@testable import VectorScriptViewerSupport

@MainActor
struct PreviewModelTests {
    @Test
    func `a source renders`() {
        let model = PreviewModel()
        model.displayScale = 1
        model.update(source: "{ size: [20, 10], elements: [{ circle: [5, 5, 4] }] }", baseURL: nil)
        #expect(model.image?.width == 20)
        #expect(model.errorMessage == nil)
        model.zoom = 2
        #expect(model.image?.width == 40)
    }

    @Test
    func `relative image paths load next to the document file`() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "PreviewModelTests-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let tile = try VectorScriptRender.Renderer(document: VectorScript.Document(json: Data("{ size: [2, 2], elements: [{ rect: [0, 0, 2, 2], fill: 'red' }] }".utf8))).data(format: .png)
        try tile.write(to: directory.appending(path: "tile.png"))
        let model = PreviewModel()
        let source = "{ size: [4, 4], elements: [{ image: 'tile.png' }] }"
        model.update(source: source, baseURL: nil)
        #expect(model.errorMessage?.contains("relative") == true)
        // The file URL arriving later, as after a first save, re-renders the same source.
        model.update(source: source, baseURL: directory.appending(path: "panel.json5"))
        #expect(model.errorMessage == nil)
        #expect(model.image != nil)
    }

    let slider = "{ animation: { duration: 2, fps: 10 }, size: [20, 10], elements: [{ rect: ['$TIME * 10', 0, 2, 10], fill: 'red' }] }"

    @Test
    func `time picks the frame`() throws {
        let model = PreviewModel()
        model.displayScale = 1
        model.update(source: slider, baseURL: nil)
        #expect(model.animation?.duration == 2)
        #expect(model.document?.elements[0].content == .shape(.rect(Rect(x: 0, y: 0, width: 2, height: 10), cornerRadius: nil)))
        model.time = 1.5
        #expect(model.document?.elements[0].content == .shape(.rect(Rect(x: 15, y: 0, width: 2, height: 10), cornerRadius: nil)))
    }

    @Test
    func `playing advances and loops`() throws {
        let model = PreviewModel()
        model.update(source: slider, baseURL: nil)
        let start = Date(timeIntervalSinceReferenceDate: 1000)
        model.play(at: start)
        #expect(model.isPlaying)
        model.advance(to: start.addingTimeInterval(0.5))
        #expect(abs(model.time - 0.5) < 1e-9)
        model.advance(to: start.addingTimeInterval(2.25))
        #expect(abs(model.time - 0.25) < 1e-9)
        model.pause()
        model.advance(to: start.addingTimeInterval(3))
        #expect(abs(model.time - 0.25) < 1e-9)
    }

    @Test
    func `a one shot animation stops at the end and replays from the start`() throws {
        let model = PreviewModel()
        model.update(source: "{ animation: { duration: 1, loop: false }, size: [4, 4], elements: [] }", baseURL: nil)
        let start = Date(timeIntervalSinceReferenceDate: 1000)
        model.play(at: start)
        model.advance(to: start.addingTimeInterval(5))
        #expect(model.time == 1)
        #expect(!model.isPlaying)
        model.play(at: start)
        #expect(model.time == 0)
    }

    @Test
    func `still documents do not play`() throws {
        let model = PreviewModel()
        model.update(source: "{ size: [4, 4], elements: [] }", baseURL: nil)
        model.play()
        #expect(!model.isPlaying)
        #expect(model.animation == nil)
    }

    @Test
    func `a broken source keeps the last image and shows the error`() {
        let model = PreviewModel()
        model.update(source: "{ size: [8, 8], elements: [] }", baseURL: nil)
        model.update(source: "{ size: [8, 8], elements: [{ circle: [1, 1, 1], fil: 'red' }] }", baseURL: nil)
        #expect(model.image != nil)
        #expect(model.errorMessage == "elements[0]: unknown key 'fil'")
        model.update(source: "{ size: [8, 8], elements: [] }", baseURL: nil)
        #expect(model.errorMessage == nil)
    }
}

struct VectorScriptDocumentTests {
    @Test
    func `the starter document is valid`() throws {
        _ = try VectorScript.Document(json: Data(VectorScriptDocument.starterSource.utf8)).resolved()
    }
}
