import CoreGraphics
import CoreText
import Foundation
import VectorScript

extension Text {
    // Glyph outlines in user space (y down), with the baseline through `at`.
    func cgPath(style: Style) throws -> CGPath {
        let name = style.font ?? "Helvetica"
        let font = try Self.font(named: name, size: style.fontSize ?? 16)
        let attributed = NSAttributedString(string: string, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
        let line = CTLineCreateWithAttributedString(attributed)
        let width = CTLineGetTypographicBounds(line, nil, nil, nil)
        let startX: Double = switch anchor {
        case .start: at.x
        case .middle: at.x - width / 2
        case .end: at.x - width
        }
        let path = CGMutablePath()
        let runs = CTLineGetGlyphRuns(line) as? [CTRun] ?? []
        for run in runs {
            let attributes = CTRunGetAttributes(run) as NSDictionary
            // Font substitution can give a run its own font.
            var runFont = font
            if let value = attributes[kCTFontAttributeName] as CFTypeRef?, CFGetTypeID(value) == CTFontGetTypeID() {
                // Checked by type ID, so the cast cannot fail.
                runFont = value as! CTFont
            }
            let count = CTRunGetGlyphCount(run)
            var glyphs = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
            CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)
            for index in 0..<count {
                guard let glyph = CTFontCreatePathForGlyph(runFont, glyphs[index], nil) else {
                    continue
                }
                // Glyphs have y up; flip them into the document's y-down space.
                let transform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: startX + positions[index].x, ty: at.y - positions[index].y)
                path.addPath(glyph, transform: transform)
            }
        }
        return path
    }

    static func font(named name: String, size: Double) throws -> CTFont {
        let font = CTFontCreateWithName(name as CFString, size, nil)
        // CoreText falls back silently; accept the result only when it is the font asked for.
        let names = [CTFontCopyPostScriptName(font), CTFontCopyFamilyName(font), CTFontCopyFullName(font)].map { $0 as String }
        guard names.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) else {
            throw RenderError.unknownFont(name)
        }
        return font
    }
}
