import Foundation

// An arithmetic expression over numbers and $NAME parameters, such as "$W / 2 + 4" or "if($BIG, 10, 5)".
// Operators: + - * / %, unary - and !, comparisons (== != < <= > >=) and logic (&& ||), which give 1 or 0.
// Functions: min, max, abs, sqrt, pow, sin, cos, tan, asin, acos, atan, atan2, floor, ceil, round, sign,
// degrees, radians, clamp, lerp, if(condition, then, else), and for animation easeIn, easeOut, easeInOut,
// smoothstep, fract, pingpong and step(t, n); pi is a constant. Trig works in radians.
public indirect enum NumberExpression: Sendable, Equatable {
    case number(Double)
    case parameter(String)
    case unary(String, NumberExpression)
    case binary(String, NumberExpression, NumberExpression)
    case call(String, [NumberExpression])

    public struct Error: Swift.Error, Equatable, CustomStringConvertible {
        public var message: String

        public var description: String {
            message
        }
    }

    public init(parsing text: String) throws(Error) {
        var parser = ExpressionParser(text)
        self = try parser.parse()
    }

    public func evaluate(_ lookup: (String) throws(Error) -> Double) throws(Error) -> Double {
        switch self {
        case .number(let value):
            return value
        case .parameter(let name):
            return try lookup(name)
        case .unary(let op, let operand):
            let value = try operand.evaluate(lookup)
            return op == "-" ? -value : (value == 0 ? 1 : 0)
        case .binary(let op, let left, let right):
            let a = try left.evaluate(lookup)
            // && and || only look at the right side when they must.
            if op == "&&" {
                return a != 0 ? (try right.evaluate(lookup) != 0 ? 1 : 0) : 0
            }
            if op == "||" {
                return a != 0 ? 1 : (try right.evaluate(lookup) != 0 ? 1 : 0)
            }
            let b = try right.evaluate(lookup)
            switch op {
            case "+": return a + b
            case "-": return a - b
            case "*": return a * b
            case "/":
                guard b != 0 else {
                    throw Error(message: "division by zero")
                }
                return a / b
            case "%":
                guard b != 0 else {
                    throw Error(message: "division by zero")
                }
                return a.truncatingRemainder(dividingBy: b)
            case "==": return a == b ? 1 : 0
            case "!=": return a != b ? 1 : 0
            case "<": return a < b ? 1 : 0
            case "<=": return a <= b ? 1 : 0
            case ">": return a > b ? 1 : 0
            default: return a >= b ? 1 : 0
            }
        case .call(let name, let arguments):
            if name == "if" {
                guard arguments.count == 3 else {
                    throw Error(message: "if takes 3 arguments")
                }
                return try arguments[try arguments[0].evaluate(lookup) != 0 ? 1 : 2].evaluate(lookup)
            }
            var values: [Double] = []
            for argument in arguments {
                values.append(try argument.evaluate(lookup))
            }
            return try Self.call(name, values)
        }
    }

    private static let unaryFunctions: [String: @Sendable (Double) -> Double] = [
        "abs": { abs($0) }, "sqrt": { $0.squareRoot() }, "sin": { Foundation.sin($0) }, "cos": { Foundation.cos($0) },
        "tan": { Foundation.tan($0) }, "asin": { Foundation.asin($0) }, "acos": { Foundation.acos($0) },
        "atan": { Foundation.atan($0) }, "floor": { $0.rounded(.down) }, "ceil": { $0.rounded(.up) },
        "round": { $0.rounded() }, "sign": { $0 > 0 ? 1 : ($0 < 0 ? -1 : 0) }, "degrees": { $0 * 180 / .pi },
        "radians": { $0 * .pi / 180 },
        // Easing, for animation: t from 0 to 1 gives 0 to 1. Inputs outside 0...1 are clamped.
        "easeIn": { let t = clamp01($0); return t * t },
        "easeOut": { let t = clamp01($0); return 1 - (1 - t) * (1 - t) },
        "easeInOut": { let t = clamp01($0); return t < 0.5 ? 2 * t * t : 1 - Foundation.pow(-2 * t + 2, 2) / 2 },
        "smoothstep": { let t = clamp01($0); return t * t * (3 - 2 * t) },
        // The part after the decimal point: 2.25 gives 0.25, -0.25 gives 0.75.
        "fract": { $0 - $0.rounded(.down) },
        // 0 up to 1 and back down over each unit: 0, 0.5 and 1 give 0, 1 and 0.
        "pingpong": { 1 - abs(2 * ($0 - $0.rounded(.down)) - 1) },
    ]

    private static func clamp01(_ value: Double) -> Double {
        Swift.min(Swift.max(value, 0), 1)
    }

    private static func call(_ name: String, _ values: [Double]) throws(Error) -> Double {
        if let function = unaryFunctions[name] {
            guard values.count == 1 else {
                throw Error(message: "\(name) takes 1 argument")
            }
            return function(values[0])
        }
        switch (name, values.count) {
        case ("min", 1...):
            return values.min() ?? 0
        case ("max", 1...):
            return values.max() ?? 0
        case ("pow", 2):
            return Foundation.pow(values[0], values[1])
        case ("atan2", 2):
            return Foundation.atan2(values[0], values[1])
        case ("clamp", 3):
            return Swift.min(Swift.max(values[0], values[1]), values[2])
        case ("lerp", 3):
            return values[0] + (values[1] - values[0]) * values[2]
        case ("step", 2):
            // t held to n steps between 0 and 1, for frame-by-frame motion.
            guard values[1] >= 1 else {
                throw Error(message: "step needs at least 1 step")
            }
            return (clamp01(values[0]) * values[1]).rounded(.down) / values[1]
        case ("min", _), ("max", _), ("pow", _), ("atan2", _), ("clamp", _), ("lerp", _), ("step", _):
            throw Error(message: "\(name) does not take \(values.count) arguments")
        default:
            throw Error(message: "unknown function '\(name)'")
        }
    }

    // Parameter names the expression reads.
    public var parameters: Set<String> {
        switch self {
        case .number: []
        case .parameter(let name): [name]
        case .unary(_, let operand): operand.parameters
        case .binary(_, let left, let right): left.parameters.union(right.parameters)
        case .call(_, let arguments): arguments.reduce(into: Set()) { $0.formUnion($1.parameters) }
        }
    }
}

struct ExpressionParser {
    private let characters: [Character]
    private var index = 0
    private let source: String

    init(_ text: String) {
        source = text
        characters = Array(text)
    }

    mutating func parse() throws(NumberExpression.Error) -> NumberExpression {
        let expression = try parseBinary(level: 0)
        skipSpaces()
        guard index == characters.count else {
            throw failure("unexpected '\(characters[index])'")
        }
        return expression
    }

    // Lowest precedence first.
    private static let levels: [[String]] = [["||"], ["&&"], ["==", "!="], ["<=", ">=", "<", ">"], ["+", "-"], ["*", "/", "%"]]

    private func failure(_ message: String) -> NumberExpression.Error {
        NumberExpression.Error(message: "bad expression '\(source)': \(message)")
    }

    private mutating func skipSpaces() {
        while index < characters.count, characters[index].isWhitespace {
            index += 1
        }
    }

    private mutating func take(_ token: String) -> Bool {
        skipSpaces()
        let tokenCharacters = Array(token)
        guard index + tokenCharacters.count <= characters.count, Array(characters[index..<(index + tokenCharacters.count)]) == tokenCharacters else {
            return false
        }
        index += tokenCharacters.count
        return true
    }

    private mutating func parseBinary(level: Int) throws(NumberExpression.Error) -> NumberExpression {
        guard level < Self.levels.count else {
            return try parseUnary()
        }
        var left = try parseBinary(level: level + 1)
        while let op = Self.levels[level].first(where: { take($0) }) {
            left = .binary(op, left, try parseBinary(level: level + 1))
        }
        return left
    }

    private mutating func parseUnary() throws(NumberExpression.Error) -> NumberExpression {
        if take("-") {
            return .unary("-", try parseUnary())
        }
        if take("!") {
            return .unary("!", try parseUnary())
        }
        if take("+") {
            return try parseUnary()
        }
        return try parsePrimary()
    }

    private mutating func parsePrimary() throws(NumberExpression.Error) -> NumberExpression {
        skipSpaces()
        guard index < characters.count else {
            throw failure("expected a value")
        }
        if take("(") {
            let inner = try parseBinary(level: 0)
            guard take(")") else {
                throw failure("missing ')'")
            }
            return inner
        }
        let character = characters[index]
        if character == "$" {
            index += 1
            let name = identifier()
            guard !name.isEmpty else {
                throw failure("expected a parameter name after '$'")
            }
            return .parameter(name)
        }
        if character.isNumber || character == "." {
            let start = index
            while index < characters.count, characters[index].isNumber || characters[index] == "." {
                index += 1
            }
            if index < characters.count, characters[index] == "e" || characters[index] == "E" {
                var cursor = index + 1
                if cursor < characters.count, characters[cursor] == "-" || characters[cursor] == "+" {
                    cursor += 1
                }
                if cursor < characters.count, characters[cursor].isNumber {
                    index = cursor
                    while index < characters.count, characters[index].isNumber {
                        index += 1
                    }
                }
            }
            guard let value = Double(String(characters[start..<index])) else {
                throw failure("bad number '\(String(characters[start..<index]))'")
            }
            return .number(value)
        }
        let name = identifier()
        guard !name.isEmpty else {
            throw failure("unexpected '\(character)'")
        }
        if name == "pi" {
            return .number(.pi)
        }
        guard take("(") else {
            throw failure("'\(name)' is not a function call or a constant; parameters start with '$'")
        }
        var arguments: [NumberExpression] = []
        if !take(")") {
            repeat {
                arguments.append(try parseBinary(level: 0))
            } while take(",")
            guard take(")") else {
                throw failure("missing ')' after the arguments to \(name)")
            }
        }
        return .call(name, arguments)
    }

    private mutating func identifier() -> String {
        let start = index
        while index < characters.count, characters[index].isLetter || characters[index].isNumber || characters[index] == "_" {
            index += 1
        }
        return String(characters[start..<index])
    }
}
