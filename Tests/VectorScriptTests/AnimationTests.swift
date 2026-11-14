import Foundation
import Testing
@testable import VectorScript

struct AnimationTests {
    let spinner = Data("""
    { animation: { duration: 2, fps: 10 },
      parameters: { ANGLE: "$TIME / $DURATION * 360" },
      size: [10, 10],
      elements: [{ rect: [0, 0, 1, 1], transform: { rotate: "$ANGLE" }, opacity: "$TIME / 2" }] }
    """.utf8)

    @Test
    func `decodes the animation block`() throws {
        let document = try Document(json: spinner)
        #expect(document.animation == Animation(duration: 2, framesPerSecond: 10, loops: true))
        #expect(try Document(json: document.jsonData()) == document)
        #expect(failure("{ animation: { duration: 0 }, size: [1, 1], elements: [] }") == "animation: an animation's duration must be positive")
        #expect(failure("{ animation: { duration: 1, speed: 2 }, size: [1, 1], elements: [] }") == "animation: unknown key 'speed'")
    }

    @Test
    func `time and duration reach expressions`() throws {
        let start = try Document(json: spinner)
        let middle = try Document(json: spinner, time: 1)
        #expect(start.elements[0].transform?.operations == [.rotate(degrees: 0, center: nil)])
        #expect(middle.elements[0].transform?.operations == [.rotate(degrees: 180, center: nil)])
        #expect(middle.elements[0].opacity == 0.5)
    }

    @Test
    func `still documents see time 0 and duration 0`() throws {
        let document = try document("{ size: ['$TIME + 1', '$DURATION + 1'], elements: [] }")
        #expect(document.size == Size(width: 1, height: 1))
    }

    @Test
    func `time and duration are reserved`() {
        #expect(failure("{ parameters: { TIME: 3 }, size: [1, 1], elements: [] }") == "parameters.TIME: TIME is set by the renderer and cannot be a parameter")
        #expect(throws: DocumentError.invalid(path: "parameters", message: "DURATION is set by the renderer; pass a time instead")) {
            try Document(json: Data("{ size: [1, 1], elements: [] }".utf8), parameters: ["DURATION": 1])
        }
    }

    @Test
    func `a source reads the document at any time`() throws {
        let source = try DocumentSource(json: spinner)
        #expect(source.animation?.duration == 2)
        #expect(try source.document(at: 0.5).elements[0].transform?.operations == [.rotate(degrees: 90, center: nil)])
    }

    @Test
    func `frame times`() {
        let looping = Animation(duration: 1, framesPerSecond: 4)
        #expect(looping.frameCount == 4)
        #expect((0..<4).map { looping.time(ofFrame: $0) } == [0, 0.25, 0.5, 0.75])
        #expect(looping.time(atElapsed: 2.25) == 0.25)
        let once = Animation(duration: 1, framesPerSecond: 4, loops: false)
        #expect(once.frameCount == 5)
        #expect(once.time(ofFrame: 4) == 1)
        #expect(once.time(atElapsed: 3) == 1)
    }
}
