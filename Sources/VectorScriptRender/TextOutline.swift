import CoreGraphics
import CoreText
import Foundation
import VectorScript

extension Text {
    // Glyph outlines in user space (y down). The first baseline runs through `at`; each later line is lineHeight
    // times fontSize lower.
    func cgPath(style: Style, baseURL: URL?) throws -> CGPath {
        let font = try Self.font(for: style, baseURL: baseURL)
        let spacing = style.letterSpacing ?? 0
        let lineAdvance = (style.lineHeight ?? 1.2) * CTFontGetSize(font)
        let path = CGMutablePath()
        for (index, line) in lines(font: font, spacing: spacing).enumerated() {
            // Trailing spaces and the spacing after the last character do not count toward the anchor.
            let width = CTLineGetTypographicBounds(line, nil, nil, nil) - CTLineGetTrailingWhitespaceWidth(line) - (CTLineGetGlyphCount(line) > 0 ? spacing : 0)
            let startX: Double = switch anchor {
            case .start: at.x
            case .middle: at.x - width / 2
            case .end: at.x - width
            }
            add(line, font: font, origin: Point(x: startX, y: at.y + Double(index) * lineAdvance), to: path)
        }
        return path
    }

    // One CTLine per "\n"-separated paragraph, or more when `width` wraps it.
    private func lines(font: CTFont, spacing: Double) -> [CTLine] {
        var attributes: [NSAttributedString.Key: Any] = [NSAttributedString.Key(kCTFontAttributeName as String): font]
        if spacing != 0 {
            attributes[NSAttributedString.Key(kCTKernAttributeName as String)] = spacing
        }
        return string.split(separator: "\n", omittingEmptySubsequences: false).flatMap { paragraph -> [CTLine] in
            let attributed = NSAttributedString(string: String(paragraph), attributes: attributes)
            guard let width, attributed.length > 0 else {
                return [CTLineCreateWithAttributedString(attributed)]
            }
            let typesetter = CTTypesetterCreateWithAttributedString(attributed)
            var lines: [CTLine] = []
            var start = 0
            while start < attributed.length {
                let count = max(1, CTTypesetterSuggestLineBreak(typesetter, start, width))
                lines.append(CTTypesetterCreateLine(typesetter, CFRange(location: start, length: count)))
                start += count
            }
            return lines
        }
    }

    private func add(_ line: CTLine, font: CTFont, origin: Point, to path: CGMutablePath) {
        let startX = origin.x
        let baseline = origin.y
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
                let transform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: startX + positions[index].x, ty: baseline - positions[index].y)
                path.addPath(glyph, transform: transform)
            }
        }
    }

    static func font(for style: Style, baseURL: URL?) throws -> CTFont {
        let size = style.fontSize ?? 16
        guard let fontFile = style.fontFile else {
            return try font(named: style.font ?? "Helvetica", size: size)
        }
        let url: URL
        do {
            url = try FileReference.url(for: fontFile, relativeTo: baseURL)
        } catch {
            throw RenderError.cannotLoadFont(file: fontFile, reason: error.description)
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw RenderError.cannotLoadFont(file: fontFile, reason: "no file at \(url.path)")
        }
        guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor], let first = descriptors.first else {
            throw RenderError.cannotLoadFont(file: fontFile, reason: "not a font file CoreText can read")
        }
        // A collection holds several faces; `font` picks one by name. It is always set once resolved, so a name
        // that matches no face falls back to the first face.
        let descriptor = descriptors.first { descriptor in
            [kCTFontNameAttribute, kCTFontFamilyNameAttribute, kCTFontDisplayNameAttribute].contains { attribute in
                (CTFontDescriptorCopyAttribute(descriptor, attribute) as? String)?.caseInsensitiveCompare(style.font ?? "") == .orderedSame
            }
        } ?? first
        return CTFontCreateWithFontDescriptor(descriptor, size, nil)
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
