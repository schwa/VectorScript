import CoreGraphics
import Foundation
import GoldenImage
import Testing
import VectorScript
import VectorScriptRender

// Renders Tests/Goldens/*.json5 at 2x and compares with the PNGs in Tests/GoldenImages. A missing golden is
// written to $TMPDIR/GoldenImages for review; copy it in to accept it.
struct GoldenTests {
    static let threshold = 60.0

    static var testsDirectory: URL {
        URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    static var cases: [String] {
        let files = (try? FileManager.default.contentsOfDirectory(at: testsDirectory.appending(path: "Goldens"), includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json5" }.map { $0.deletingPathExtension().lastPathComponent }.sorted()
    }

    @Test(arguments: cases)
    func `rendering matches the golden image`(name: String) throws {
        let document = try Document(contentsOf: Self.testsDirectory.appending(path: "Goldens/\(name).json5"))
        let image = try Renderer(document: document).cgImage(scale: 2)
        let golden = GoldenImageComparison(imageDirectory: Self.testsDirectory.appending(path: "GoldenImages"), options: .ignoreEdgeAAHalos, psnrThreshold: Self.threshold)
        let outcome = try golden.compare(image: image, toGoldenImageNamed: name)
        #expect(outcome.isMatch, "PSNR \(outcome.psnr); see \(outcome.savedImageURL?.path ?? "-")")
    }

    @Test
    func `there is a golden case for every feature area`() {
        #expect(Set(Self.cases) == ["blend-modes", "clipping", "filters", "images", "letter-spacing", "markers", "masks", "paint", "paths", "patterns", "shapes", "strokes", "structure", "text", "text-lines", "transforms"])
    }
}
