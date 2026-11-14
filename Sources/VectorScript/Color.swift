// An sRGB color with straight alpha; components are 0...1.
public struct Color: Sendable, Equatable, Codable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public static let black = Color(red: 0, green: 0, blue: 0)
    public static let white = Color(red: 1, green: 1, blue: 1)
    public static let transparent = Color(red: 0, green: 0, blue: 0, alpha: 0)

    public enum ParseError: Error, Equatable, CustomStringConvertible {
        case unknownColor(String)

        public var description: String {
            switch self {
            case .unknownColor(let text): "unknown color '\(text)'"
            }
        }
    }

    // "#rgb", "#rgba", "#rrggbb", "#rrggbbaa", a CSS color name, or "transparent".
    public init(parsing text: String) throws(ParseError) {
        if text.hasPrefix("#") {
            let digits = Array(text.dropFirst())
            let values = digits.compactMap(\.hexDigitValue)
            guard values.count == digits.count else {
                throw .unknownColor(text)
            }
            switch values.count {
            case 3, 4:
                let channels = values.map { Double($0 * 17) / 255 }
                self.init(red: channels[0], green: channels[1], blue: channels[2], alpha: channels.count == 4 ? channels[3] : 1)
            case 6, 8:
                let channels = stride(from: 0, to: values.count, by: 2).map { Double(values[$0] * 16 + values[$0 + 1]) / 255 }
                self.init(red: channels[0], green: channels[1], blue: channels[2], alpha: channels.count == 4 ? channels[3] : 1)
            default:
                throw .unknownColor(text)
            }
        } else if text == "transparent" {
            self = .transparent
        } else if let rgb = Self.named[text.lowercased()] {
            self.init(red: Double((rgb >> 16) & 0xff) / 255, green: Double((rgb >> 8) & 0xff) / 255, blue: Double(rgb & 0xff) / 255)
        } else {
            throw .unknownColor(text)
        }
    }

    // "#rrggbb", or "#rrggbbaa" when not opaque.
    public var hexString: String {
        let channels = alpha == 1 ? [red, green, blue] : [red, green, blue, alpha]
        return "#" + channels.map { channel in
            let byte = Int((min(max(channel, 0), 1) * 255).rounded())
            return (byte < 16 ? "0" : "") + String(byte, radix: 16)
        }.joined()
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
        try container.encode(hexString)
    }
}
