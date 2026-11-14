// How the viewBox fits the canvas when their aspect ratios differ. Same syntax as SVG's preserveAspectRatio:
// "none", or "<align> [meet|slice]" with align xMinYMin ... xMaxYMax.
public enum AspectRatio: Sendable, Equatable, Codable {
    public enum Alignment: Sendable, Equatable {
        case min, mid, max

        var fraction: Double {
            switch self {
            case .min: 0
            case .mid: 0.5
            case .max: 1
            }
        }
    }

    public enum Scaling: String, Sendable, Equatable {
        // The whole viewBox shows, with space left over on one axis.
        case meet
        // The viewBox fills the canvas and is cut off on one axis.
        case slice
    }

    // Each axis scales on its own.
    case none
    case uniform(x: Alignment, y: Alignment, scaling: Scaling)

    public struct ParseError: Error, Equatable, CustomStringConvertible {
        public var text: String

        public var description: String {
            "bad preserveAspectRatio '\(text)' (expected none, or xMinYMin ... xMaxYMax, then meet or slice)"
        }
    }

    public init(parsing text: String) throws(ParseError) {
        let words = text.split(separator: " ").map(String.init)
        guard let first = words.first, words.count <= 2 else {
            throw ParseError(text: text)
        }
        if first == "none", words.count == 1 {
            self = .none
            return
        }
        let alignments: [String: Alignment] = ["Min": .min, "Mid": .mid, "Max": .max]
        guard first.count == 8, first.hasPrefix("x"), first.dropFirst(4).hasPrefix("Y"), let x = alignments[String(first.dropFirst().prefix(3))], let y = alignments[String(first.suffix(3))] else {
            throw ParseError(text: text)
        }
        var scaling = Scaling.meet
        if words.count == 2 {
            guard let parsed = Scaling(rawValue: words[1]) else {
                throw ParseError(text: text)
            }
            scaling = parsed
        }
        self = .uniform(x: x, y: y, scaling: scaling)
    }

    public var string: String {
        switch self {
        case .none:
            return "none"
        case .uniform(let x, let y, let scaling):
            let names: [Alignment: String] = [.min: "Min", .mid: "Mid", .max: "Max"]
            return "x\(names[x] ?? "Mid")Y\(names[y] ?? "Mid") \(scaling.rawValue)"
        }
    }

    // Maps `viewBox` onto `bounds`. Slice leaves part of the viewBox outside bounds; callers clip.
    public func matrix(mapping viewBox: Rect, onto bounds: Rect) -> Matrix {
        var scaleX = bounds.size.width / viewBox.size.width
        var scaleY = bounds.size.height / viewBox.size.height
        var offsetX = bounds.origin.x
        var offsetY = bounds.origin.y
        if case .uniform(let x, let y, let scaling) = self {
            let scale = scaling == .meet ? min(scaleX, scaleY) : max(scaleX, scaleY)
            scaleX = scale
            scaleY = scale
            offsetX += (bounds.size.width - viewBox.size.width * scale) * x.fraction
            offsetY += (bounds.size.height - viewBox.size.height * scale) * y.fraction
        }
        return Matrix(a: scaleX, b: 0, c: 0, d: scaleY, tx: offsetX - viewBox.origin.x * scaleX, ty: offsetY - viewBox.origin.y * scaleY)
    }

    public init(from decoder: any Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        do {
            try self.init(parsing: text)
        } catch {
            throw decoder.corrupted(error.description)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(string)
    }
}

extension AspectRatio.Alignment: Hashable {}
