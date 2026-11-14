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
        if let onPath {
            if let line = lines(font: font, spacing: spacing).first {
                add(line, font: font, along: PathWalker(Shape.path(onPath).cgPath), start: anchored(offset, width: width(of: line, spacing: spacing)), to: path)
            }
            return path
        }
        for (index, line) in lines(font: font, spacing: spacing).enumerated() {
            let startX = anchored(at.x, width: width(of: line, spacing: spacing))
            add(line, font: font, origin: Point(x: startX, y: at.y + Double(index) * lineAdvance), to: path)
        }
        return path
    }

    // Trailing spaces and the spacing after the last character do not count toward the anchor.
    private func width(of line: CTLine, spacing: Double) -> Double {
        CTLineGetTypographicBounds(line, nil, nil, nil) - CTLineGetTrailingWhitespaceWidth(line) - (CTLineGetGlyphCount(line) > 0 ? spacing : 0)
    }

    private func anchored(_ position: Double, width: Double) -> Double {
        switch anchor {
        case .start: position
        case .middle: position - width / 2
        case .end: position - width
        }
    }

    // Places each glyph with the middle of its advance on the path, turned to the path's direction there. Glyphs
    // whose middle falls off either end are left out, as in SVG.
    private func add(_ line: CTLine, font: CTFont, along walker: PathWalker, start: Double, to path: CGMutablePath) {
        for run in CTLineGetGlyphRuns(line) as? [CTRun] ?? [] {
            let runFont = Self.font(of: run, fallback: font)
            let count = CTRunGetGlyphCount(run)
            var glyphs = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            var advances = [CGSize](repeating: .zero, count: count)
            CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
            CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)
            CTRunGetAdvances(run, CFRange(location: 0, length: count), &advances)
            for index in 0..<count {
                let middle = start + positions[index].x + advances[index].width / 2
                guard let glyph = CTFontCreatePathForGlyph(runFont, glyphs[index], nil), let place = walker.place(at: middle) else {
                    continue
                }
                // Flip the glyph to y down, center it on the point, turn it, then move it there.
                let transform = CGAffineTransform(translationX: place.point.x, y: place.point.y).rotated(by: place.angle).translatedBy(x: -advances[index].width / 2, y: -positions[index].y).scaledBy(x: 1, y: -1)
                path.addPath(glyph, transform: transform)
            }
        }
    }

    static func font(of run: CTRun, fallback: CTFont) -> CTFont {
        let attributes = CTRunGetAttributes(run) as NSDictionary
        if let value = attributes[kCTFontAttributeName] as CFTypeRef?, CFGetTypeID(value) == CTFontGetTypeID() {
            // Checked by type ID, so the cast cannot fail.
            return value as! CTFont
        }
        return fallback
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
            // Font substitution can give a run its own font.
            let runFont = Self.font(of: run, fallback: font)
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
