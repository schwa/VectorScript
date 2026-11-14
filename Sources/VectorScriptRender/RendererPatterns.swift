import CoreGraphics
import VectorScript

extension Renderer {
    static let maximumPatternTiles = 1_000_000
    static let maximumPatternPixels = 64 * 1024 * 1024

    func fill(_ area: CGPath, fillRule: CGPathFillRule, with pattern: Pattern, in context: CGContext) throws {
        let patternMatrix = (pattern.transform?.matrix ?? .identity).cgAffineTransform
        // Tile indices covering the area, in pattern space.
        let bounds = area.boundingBoxOfPath.applying(patternMatrix.inverted())
        guard !bounds.isNull, bounds.width.isFinite, bounds.height.isFinite else {
            return
        }
        let columns = Int(floor(bounds.minX / pattern.size.width))...Int(floor(bounds.maxX / pattern.size.width))
        let rows = Int(floor(bounds.minY / pattern.size.height))...Int(floor(bounds.maxY / pattern.size.height))
        let tileCount = Double(columns.count) * Double(rows.count)
        guard tileCount <= Double(Self.maximumPatternTiles) else {
            throw RenderError.tooManyPatternTiles(Int(min(tileCount, Double(Int.max))))
        }
        // Only bitmap contexts have bits per pixel.
        if context.bitsPerPixel > 0, let image = try tiledImage(pattern, columns: columns, rows: rows, deviceMatrix: patternMatrix.concatenating(context.ctm)) {
            context.saveGState()
            defer {
                context.restoreGState()
            }
            context.addPath(area)
            context.clip(using: fillRule)
            context.concatenate(patternMatrix)
            let rect = CGRect(x: Double(columns.lowerBound) * pattern.size.width, y: Double(rows.lowerBound) * pattern.size.height, width: Double(columns.count) * pattern.size.width, height: Double(rows.count) * pattern.size.height)
            // The image is stored top row first; flip so it lands upright in the y-down space.
            context.translateBy(x: 0, y: rect.minY + rect.maxY)
            context.scaleBy(x: 1, y: -1)
            context.interpolationQuality = .high
            context.draw(image, in: rect)
        } else {
            try fillWithCGPattern(area, fillRule: fillRule, pattern: pattern, patternMatrix: patternMatrix, in: context)
        }
    }

    // Draws the tiles on a pixel grid where every tile edge falls on a pixel boundary, so neighboring tiles meet
    // without antialiased seams. CGPattern leaves hairline seams between rotated tiles. Nil when the image would be
    // too big.
    private func tiledImage(_ pattern: Pattern, columns: ClosedRange<Int>, rows: ClosedRange<Int>, deviceMatrix: CGAffineTransform) throws -> CGImage? {
        let scale = max(1, abs(deviceMatrix.a * deviceMatrix.d - deviceMatrix.b * deviceMatrix.c).squareRoot())
        let cellWidth = max(1, Int((pattern.size.width * scale).rounded()))
        let cellHeight = max(1, Int((pattern.size.height * scale).rounded()))
        let width = cellWidth * columns.count
        let height = cellHeight * rows.count
        guard width * height <= Self.maximumPatternPixels, let colorSpace = CGColorSpace(name: CGColorSpace.sRGB), let tileContext = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        tileContext.translateBy(x: 0, y: CGFloat(height))
        tileContext.scaleBy(x: 1, y: -1)
        for row in 0..<rows.count {
            for column in 0..<columns.count {
                tileContext.saveGState()
                tileContext.clip(to: CGRect(x: column * cellWidth, y: row * cellHeight, width: cellWidth, height: cellHeight))
                tileContext.translateBy(x: CGFloat(column * cellWidth), y: CGFloat(row * cellHeight))
                tileContext.scaleBy(x: Double(cellWidth) / pattern.size.width, y: Double(cellHeight) / pattern.size.height)
                for element in pattern.elements {
                    try draw(element, in: tileContext)
                }
                tileContext.restoreGState()
            }
        }
        return tileContext.makeImage()
    }

    // Keeps PDF output vector.
    private func fillWithCGPattern(_ area: CGPath, fillRule: CGPathFillRule, pattern: Pattern, patternMatrix: CGAffineTransform, in context: CGContext) throws {
        let cell = PatternCell { cellContext in
            for element in pattern.elements {
                try draw(element, in: cellContext)
            }
        }
        var callbacks = CGPatternCallbacks(version: 0, drawPattern: { info, cellContext in
            guard let info else {
                return
            }
            Unmanaged<PatternCell>.fromOpaque(info).takeUnretainedValue().draw(in: cellContext)
        }, releaseInfo: { info in
            if let info {
                Unmanaged<PatternCell>.fromOpaque(info).release()
            }
        })
        let cellRect = CGRect(x: 0, y: 0, width: pattern.size.width, height: pattern.size.height)
        // Pattern space is relative to the context's base space, not its current transform.
        guard let cgPattern = CGPattern(info: Unmanaged.passRetained(cell).toOpaque(), bounds: cellRect, matrix: patternMatrix.concatenating(context.ctm), xStep: pattern.size.width, yStep: pattern.size.height, tiling: .constantSpacing, isColored: true, callbacks: &callbacks), let patternSpace = CGColorSpace(patternBaseSpace: nil) else {
            throw RenderError.cannotCreateContext
        }
        context.saveGState()
        context.setFillColorSpace(patternSpace)
        var alpha: CGFloat = 1
        context.setFillPattern(cgPattern, colorComponents: &alpha)
        context.addPath(area)
        context.fillPath(using: fillRule)
        context.restoreGState()
        if let error = cell.error {
            throw error
        }
    }
}
