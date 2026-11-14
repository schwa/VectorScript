import CoreGraphics
import Foundation
import ImageIO
import Testing

struct CommandLineTests {
    // The vectorscript binary sits beside the test bundle in the build directory.
    static var executable: URL? {
        var directory = Bundle(for: Marker.self).bundleURL.deletingLastPathComponent()
        for _ in 0..<3 {
            let candidate = directory.appending(path: "vectorscript")
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
            directory.deleteLastPathComponent()
        }
        return nil
    }

    final class Marker {}

    func run(_ arguments: [String]) throws -> (status: Int32, output: String) {
        let executable = try #require(Self.executable)
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        return (process.terminationStatus, output)
    }

    func temporaryFile(_ name: String, contents: String? = nil) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "VectorScriptCLITests-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: name)
        if let contents {
            try Data(contents.utf8).write(to: url)
        }
        return url
    }

    @Test
    func `renders a png at the requested size`() throws {
        let input = try temporaryFile("dot.json5", contents: "{ size: [10, 20], elements: [{ circle: [5, 5, 4] }] }")
        let output = input.deletingLastPathComponent().appending(path: "out.png")
        let result = try run(["render", input.path, "-o", output.path, "--scale", "3"])
        #expect(result.status == 0, "\(result.output)")
        let source = try #require(CGImageSourceCreateWithURL(output as CFURL, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == 30)
        #expect(image.height == 60)
    }

    @Test
    func `defaults to a png beside the input`() throws {
        let input = try temporaryFile("plain.json", contents: "{ \"size\": [4, 4], \"elements\": [] }")
        let result = try run(["render", input.path])
        #expect(result.status == 0, "\(result.output)")
        #expect(FileManager.default.fileExists(atPath: input.deletingPathExtension().appendingPathExtension("png").path))
    }

    @Test
    func `infers pdf from the extension`() throws {
        let input = try temporaryFile("doc.json5", contents: "{ size: [4, 4], elements: [] }")
        let output = input.deletingLastPathComponent().appending(path: "doc.pdf")
        #expect(try run(["render", input.path, "-o", output.path]).status == 0)
        #expect(try Data(contentsOf: output).starts(with: Array("%PDF".utf8)))
    }

    @Test
    func `validate reports the coding path and fails`() throws {
        let input = try temporaryFile("bad.json5", contents: "{ size: [4, 4], elements: [{ circle: [1, 1, 1], fil: 'red' }] }")
        let result = try run(["validate", input.path])
        #expect(result.status != 0)
        #expect(result.output.contains("elements[0]: unknown key 'fil'"))
    }
}
