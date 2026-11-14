import CoreText
import Foundation
import Testing
import VectorScript
@testable import VectorScriptRender

struct FontFileTests {
    static let singleFace = URL(filePath: "/System/Library/Fonts/Supplemental/Andale Mono.ttf")
    static let collection = URL(filePath: "/System/Library/Fonts/Supplemental/AmericanTypewriter.ttc")

    func postScriptName(_ style: Style, baseURL: URL? = nil) throws -> String {
        CTFontCopyPostScriptName(try Text.font(for: style, baseURL: baseURL)) as String
    }

    @Test(.enabled(if: FileManager.default.fileExists(atPath: singleFace.path)))
    func `a font file replaces the named font`() throws {
        // The resolved style always has a font name; with a file, it only picks a face.
        #expect(try postScriptName(Style(font: "Helvetica", fontSize: 12, fontFile: Self.singleFace.path)) == "AndaleMono")
    }

    @Test(.enabled(if: FileManager.default.fileExists(atPath: collection.path)))
    func `font picks a face in a collection`() throws {
        let bold = try postScriptName(Style(font: "AmericanTypewriter-Bold", fontSize: 12, fontFile: Self.collection.path))
        #expect(bold == "AmericanTypewriter-Bold")
    }

    @Test(.enabled(if: FileManager.default.fileExists(atPath: singleFace.path)))
    func `relative font files load next to the document`() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "FontFileTests-\(UUID())")
        try FileManager.default.createDirectory(at: directory.appending(path: "fonts"), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: Self.singleFace, to: directory.appending(path: "fonts/mono.ttf"))
        let url = directory.appending(path: "doc.json5")
        try Data("{ size: [120, 30], elements: [{ text: 'iiii', at: [5, 22], fontSize: 20, fontFile: 'fonts/mono.ttf' }] }".utf8).write(to: url)
        let mono = Bitmap(try Renderer(document: Document(contentsOf: url)).cgImage())
        let proportional = try render("{ size: [120, 30], elements: [{ text: 'iiii', at: [5, 22], fontSize: 20 }] }")
        // Monospaced i's are far wider than Helvetica's.
        func width(_ bitmap: Bitmap) -> Int {
            let inked = (0..<bitmap.width).filter { x in (0..<bitmap.height).contains { bitmap[x, $0][3] > 0 } }
            return (inked.last ?? 0) - (inked.first ?? 0)
        }
        #expect(width(mono) > width(proportional) * 2)
    }

    @Test
    func `a missing font file is an error`() throws {
        let document = try Document(json: Data("{ size: [10, 10], elements: [{ text: 'A', at: [0, 8], fontFile: '/nonexistent/font.ttf' }] }".utf8))
        #expect(throws: RenderError.cannotLoadFont(file: "/nonexistent/font.ttf", reason: "no file at /nonexistent/font.ttf")) {
            try Renderer(document: document).cgImage()
        }
    }

    @Test
    func `a file that is not a font is an error`() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "FontFileTests-\(UUID()).ttf")
        try Data("not a font".utf8).write(to: url)
        let document = try Document(json: Data("{ size: [10, 10], elements: [{ text: 'A', at: [0, 8], fontFile: '\(url.path)' }] }".utf8))
        #expect(throws: RenderError.cannotLoadFont(file: url.path, reason: "not a font file CoreText can read")) {
            try Renderer(document: document).cgImage()
        }
    }
}
