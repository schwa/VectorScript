import Foundation

public extension CodingUserInfoKey {
    // A `ParameterEnvironment` that expressions in a document read $NAME from.
    static let vectorScriptParameters = CodingUserInfoKey(rawValue: "vectorScriptParameters")!
}

// A value for a document parameter, from the document's "parameters" block or passed in to override it.
public enum ParameterValue: Sendable, Equatable, ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral {
    case number(Double)
    case color(Color)
    // Evaluated like a number written in the document, so it may read other parameters.
    case expression(String)

    public init(floatLiteral value: Double) {
        self = .number(value)
    }

    public init(integerLiteral value: Int) {
        self = .number(Double(value))
    }

    // A number, a "#" color, or an expression.
    public init(parsing text: String) throws {
        if let number = Double(text) {
            self = .number(number)
        } else if text.hasPrefix("#") {
            self = .color(try Color(parsing: text))
        } else {
            _ = try NumberExpression(parsing: text)
            self = .expression(text)
        }
    }
}

// The evaluated parameters of one document.
public final class ParameterEnvironment: Sendable {
    public let numbers: [String: Double]
    public let colors: [String: Color]

    init(numbers: [String: Double], colors: [String: Color]) {
        self.numbers = numbers
        self.colors = colors
    }

    public static let empty = ParameterEnvironment(numbers: [:], colors: [:])

    public func number(_ name: String) throws(NumberExpression.Error) -> Double {
        if let value = numbers[name] {
            return value
        }
        if colors[name] != nil {
            throw NumberExpression.Error(message: "$\(name) is a color, not a number")
        }
        throw NumberExpression.Error(message: "no parameter named '\(name)'")
    }

    public func evaluate(_ text: String) throws(NumberExpression.Error) -> Double {
        try NumberExpression(parsing: text).evaluate { name throws(NumberExpression.Error) in
            try number(name)
        }
    }

    // Defaults from the document, replaced by `overrides`. Parameters may read each other, in any order.
    static func make(defaults: [String: ParameterValue], overrides: [String: ParameterValue]) throws -> ParameterEnvironment {
        for name in overrides.keys.sorted() where defaults[name] == nil {
            throw DocumentError.invalid(path: "parameters", message: "'\(name)' is set from outside but is not a parameter of the document")
        }
        let values = defaults.merging(overrides) { _, override in override }
        var numbers: [String: Double] = [:]
        var colors: [String: Color] = [:]
        var expressions: [String: NumberExpression] = [:]
        for (name, value) in values {
            switch value {
            case .number(let number): numbers[name] = number
            case .color(let color): colors[name] = color
            case .expression(let text):
                do {
                    expressions[name] = try NumberExpression(parsing: text)
                } catch {
                    throw DocumentError.invalid(path: "parameters.\(name)", message: error.description)
                }
            }
        }
        // Evaluate on demand, so order does not matter; `visiting` catches parameters that need themselves.
        var visiting: [String] = []
        func value(of name: String) throws(NumberExpression.Error) -> Double {
            if let number = numbers[name] {
                return number
            }
            guard let expression = expressions[name] else {
                throw NumberExpression.Error(message: colors[name] != nil ? "$\(name) is a color, not a number" : "no parameter named '\(name)'")
            }
            guard !visiting.contains(name) else {
                throw NumberExpression.Error(message: "parameter cycle: \((visiting + [name]).map { "$" + $0 }.joined(separator: " -> "))")
            }
            visiting.append(name)
            let result = try expression.evaluate { inner throws(NumberExpression.Error) in
                try value(of: inner)
            }
            visiting.removeLast()
            numbers[name] = result
            return result
        }
        for name in expressions.keys.sorted() {
            do {
                _ = try value(of: name)
            } catch {
                throw DocumentError.invalid(path: "parameters.\(name)", message: error.description)
            }
        }
        return ParameterEnvironment(numbers: numbers, colors: colors)
    }
}

// A number in a document: a JSON number, or a string expression such as "$W / 2".
struct Number: Decodable {
    var value: Double

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let number = try? container.decode(Double.self) {
            value = number
            return
        }
        guard let text = try? container.decode(String.self) else {
            throw decoder.corrupted("expected a number or an expression")
        }
        let environment = decoder.userInfo[.vectorScriptParameters] as? ParameterEnvironment ?? .empty
        do {
            value = try environment.evaluate(text)
        } catch {
            throw decoder.corrupted(error.description)
        }
    }
}

extension Decoder {
    var parameters: ParameterEnvironment {
        userInfo[.vectorScriptParameters] as? ParameterEnvironment ?? .empty
    }

    // Replaces each {expression} in path data or a transform string with its value.
    func substitutingExpressions(in text: String) throws -> String {
        guard text.contains("{") else {
            return text
        }
        var result = ""
        var rest = Substring(text)
        while let open = rest.firstIndex(of: "{") {
            result += rest[..<open]
            guard let close = rest[open...].firstIndex(of: "}") else {
                throw corrupted("missing '}' in '\(text)'")
            }
            do {
                // Spaces keep "M{$X}{$Y}" from running the two numbers together.
                result += " " + formatNumber(try parameters.evaluate(String(rest[rest.index(after: open)..<close]))) + " "
            } catch {
                throw corrupted(error.description)
            }
            rest = rest[rest.index(after: close)...]
        }
        return result + rest
    }
}

extension KeyedDecodingContainer where K == AnyKey {
    func decodeNumber(_ name: String) throws -> Double {
        try decode(Number.self, name).value
    }

    func decodeNumberIfPresent(_ name: String) throws -> Double? {
        try decodeIfPresent(Number.self, name)?.value
    }
}
