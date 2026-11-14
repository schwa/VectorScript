import CoreGraphics
import Foundation
import Testing
import VectorScript
import VectorScriptRender

struct ExampleTests {
    static var packageDirectory: URL {
        URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    static func files(in directory: String) -> [URL] {
        let url = packageDirectory.appending(path: directory)
        let files = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
        return files.filter { ["json", "json5"].contains($0.pathExtension) }.sorted { $0.path < $1.path }
    }

    static var examples: [String] {
        files(in: "Examples").map(\.lastPathComponent)
    }

    static var uvx: URL? {
        ["/opt/homebrew/bin/uvx", "/usr/local/bin/uvx", NSHomeDirectory() + "/.local/bin/uvx", NSHomeDirectory() + "/.cargo/bin/uvx"]
            .map { URL(filePath: $0) }
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    @Test
    func `there are examples`() {
        #expect(!Self.examples.isEmpty)
    }

    @Test(arguments: examples)
    func `every example parses and renders`(name: String) throws {
        let document = try Document(contentsOf: Self.packageDirectory.appending(path: "Examples/\(name)"))
        let image = try Renderer(document: document).cgImage()
        #expect(image.width == Int(document.size.width))
    }

    @Test(.enabled(if: uvx != nil, "needs uvx to run check-jsonschema"))
    func `examples and goldens match the schema`() throws {
        let files = Self.files(in: "Examples") + Self.files(in: "Tests/Goldens")
        let process = Process()
        process.executableURL = Self.uvx
        process.arguments = ["--with", "json5", "check-jsonschema", "--schemafile", Self.packageDirectory.appending(path: "Schema/vectorscript.schema.json").path] + files.map(\.path)
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        #expect(process.terminationStatus == 0, "\(output)")
    }
}
