import CoreGraphics
import Foundation
import ImageIO
import Testing
import VectorScript
import VectorScriptRender

struct AnimationOutputTests {
    // A red square sliding right over one second at 4 fps.
    let slider = Data("{ animation: { duration: 1, fps: 4 }, size: [20, 10], elements: [{ rect: ['$TIME * 20', 0, 5, 10], fill: 'red' }] }".utf8)

    func temporaryURL(_ name: String) -> URL {
        FileManager.default.temporaryDirectory.appending(path: "AnimationOutputTests-\(UUID())").appending(path: name)
    }

    @Test
    func `frames follow the time`() throws {
        let frames = try DocumentSource(json: slider).frames()
        #expect(frames.map(\.time) == [0, 0.25, 0.5, 0.75])
        let reds = frames.map { frame in
            let bitmap = Bitmap(frame.image)
            return (0..<bitmap.width).first { bitmap[$0, 5] == [255, 0, 0, 255] }
        }
        #expect(reds == [0, 5, 10, 15])
    }

    @Test(arguments: AnimationFormat.allCases)
    func `writes animated files`(format: AnimationFormat) throws {
        let url = temporaryURL("slider.\(format.rawValue)")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try DocumentSource(json: slider).writeAnimation(to: url, format: format, scale: 2)
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        #expect(CGImageSourceGetCount(source) == 4)
        let frame = try #require(CGImageSourceCreateImageAtIndex(source, 1, nil))
        #expect(frame.width == 40)
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 1, nil) as? [CFString: Any])
        let dictionary = properties[format == .png ? kCGImagePropertyPNGDictionary : kCGImagePropertyGIFDictionary] as? [CFString: Any]
        let delay = dictionary?[format == .png ? kCGImagePropertyAPNGDelayTime : kCGImagePropertyGIFDelayTime] as? Double
        #expect(abs((delay ?? 0) - 0.25) < 0.01)
    }

    @Test
    func `writes numbered frames`() throws {
        let directory = temporaryURL("frames")
        let urls = try DocumentSource(json: slider).writeFrames(to: directory)
        #expect(urls.map(\.lastPathComponent) == ["frame-0001.png", "frame-0002.png", "frame-0003.png", "frame-0004.png"])
        #expect(urls.allSatisfy { FileManager.default.fileExists(atPath: $0.path) })
    }

    @Test
    func `still documents cannot animate`() throws {
        let source = try DocumentSource(json: Data("{ size: [1, 1], elements: [] }".utf8))
        #expect(throws: AnimationError.notAnimated) {
            try source.frames()
        }
    }
}
