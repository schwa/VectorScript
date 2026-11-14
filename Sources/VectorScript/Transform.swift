import Foundation

public enum TransformOperation: Sendable, Equatable, Codable {
    case translate(x: Double, y: Double)
    // Degrees, clockwise (y points down).
    case rotate(degrees: Double, center: Point?)
    case scale(x: Double, y: Double)
    case skewX(degrees: Double)
    case skewY(degrees: Double)
    case matrix(Matrix)

    static let typeKeys: Set<String> = ["translate", "rotate", "scale", "skewX", "skewY", "matrix"]

    public var matrix: Matrix {
        switch self {
        case .translate(let x, let y):
            return Matrix(a: 1, b: 0, c: 0, d: 1, tx: x, ty: y)
        case .rotate(let degrees, let center):
            let radians = degrees * .pi / 180
            let rotation = Matrix(a: cos(radians), b: sin(radians), c: -sin(radians), d: cos(radians), tx: 0, ty: 0)
            guard let center else {
                return rotation
            }
            return TransformOperation.translate(x: center.x, y: center.y).matrix * rotation * TransformOperation.translate(x: -center.x, y: -center.y).matrix
        case .scale(let x, let y):
            return Matrix(a: x, b: 0, c: 0, d: y, tx: 0, ty: 0)
        case .skewX(let degrees):
            return Matrix(a: 1, b: 0, c: tan(degrees * .pi / 180), d: 1, tx: 0, ty: 0)
        case .skewY(let degrees):
            return Matrix(a: 1, b: tan(degrees * .pi / 180), c: 0, d: 1, tx: 0, ty: 0)
        case .matrix(let matrix):
            return matrix
        }
    }

    // name and arguments, as in the SVG syntax "name(arguments)".
    init(name: String, arguments: [Double]) throws(TransformError) {
        switch (name, arguments.count) {
        case ("translate", 1):
            self = .translate(x: arguments[0], y: 0)
        case ("translate", 2):
            self = .translate(x: arguments[0], y: arguments[1])
        case ("rotate", 1):
            self = .rotate(degrees: arguments[0], center: nil)
        case ("rotate", 3):
            self = .rotate(degrees: arguments[0], center: Point(x: arguments[1], y: arguments[2]))
        case ("scale", 1):
            self = .scale(x: arguments[0], y: arguments[0])
        case ("scale", 2):
            self = .scale(x: arguments[0], y: arguments[1])
        case ("skewX", 1):
            self = .skewX(degrees: arguments[0])
        case ("skewY", 1):
            self = .skewY(degrees: arguments[0])
        case ("matrix", 6):
            self = .matrix(Matrix(a: arguments[0], b: arguments[1], c: arguments[2], d: arguments[3], tx: arguments[4], ty: arguments[5]))
        default:
            if Self.typeKeys.contains(name) {
                throw .wrongArgumentCount(operation: name, count: arguments.count)
            }
            throw .unknownOperation(name)
        }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: AnyKey.self)
        let type = try container.singleKey(from: Self.typeKeys, what: "a transform operation")
        try container.rejectUnknownKeys(allowed: [type])
        let value = try container.superDecoder(forKey: AnyKey(type))
        let arguments: [Double]
        switch type {
        case "translate":
            arguments = try value.numbers(count: 2)
        case "rotate":
            arguments = try value.numberOrNumbers(count: 3)
        case "scale":
            arguments = try value.numberOrNumbers(count: 2)
        case "matrix":
            arguments = try value.numbers(count: 6)
        default:
            arguments = [try Number(from: value).value]
        }
        do {
            try self.init(name: type, arguments: arguments)
        } catch {
            throw value.corrupted(error.description)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: AnyKey.self)
        switch self {
        case .translate(let x, let y):
            try container.encode([x, y], "translate")
        case .rotate(let degrees, let center):
            if let center {
                try container.encode([degrees, center.x, center.y], "rotate")
            } else {
                try container.encode(degrees, "rotate")
            }
        case .scale(let x, let y):
            if x == y {
                try container.encode(x, "scale")
            } else {
                try container.encode([x, y], "scale")
            }
        case .skewX(let degrees):
            try container.encode(degrees, "skewX")
        case .skewY(let degrees):
            try container.encode(degrees, "skewY")
        case .matrix(let matrix):
            try container.encode([matrix.a, matrix.b, matrix.c, matrix.d, matrix.tx, matrix.ty], "matrix")
        }
    }
}

public enum TransformError: Error, Equatable, CustomStringConvertible {
    case syntax(String)
    case unknownOperation(String)
    case wrongArgumentCount(operation: String, count: Int)

    public var description: String {
        switch self {
        case .syntax(let reason): "bad transform: \(reason)"
        case .unknownOperation(let name): "unknown transform operation '\(name)'"
        case .wrongArgumentCount(let operation, let count): "\(operation) does not take \(count) numbers"
        }
    }
}

// Operations in SVG order: the first is outermost.
public struct Transform: Sendable, Equatable, Codable {
    public var operations: [TransformOperation]

    public init(_ operations: [TransformOperation]) {
        self.operations = operations
    }

    public init(matrix: Matrix) {
        operations = [.matrix(matrix)]
    }

    public var matrix: Matrix {
        operations.reduce(Matrix.identity) { $0 * $1.matrix }
    }

    // SVG transform syntax: "translate(128 128) rotate(45) scale(2)".
    public init(parsing text: String) throws(TransformError) {
        var operations: [TransformOperation] = []
        var rest = Substring(text)
        while true {
            rest = rest.drop { $0.isWhitespace || $0 == "," }
            if rest.isEmpty {
                break
            }
            guard let open = rest.firstIndex(of: "("), let close = rest.firstIndex(of: ")"), open < close else {
                throw .syntax("expected name(numbers) at '\(rest)'")
            }
            let name = rest[..<open].trimmingCharacters(in: .whitespaces)
            var scanner = NumberScanner(String(rest[rest.index(after: open)..<close]))
            var arguments: [Double] = []
            while !scanner.isAtEnd {
                guard let number = scanner.number() else {
                    throw .syntax("bad number in \(name)(...)")
                }
                arguments.append(number)
            }
            operations.append(try TransformOperation(name: name, arguments: arguments))
            rest = rest[rest.index(after: close)...]
        }
        self.operations = operations
    }

    public init(from decoder: any Decoder) throws {
        if let source = try? decoder.singleValueContainer().decode(String.self) {
            let text = try decoder.substitutingExpressions(in: source)
            do {
                try self.init(parsing: text)
            } catch {
                throw decoder.corrupted(error.description)
            }
        } else if let operations = try? [TransformOperation](from: decoder) {
            self.init(operations)
        } else if (try? decoder.unkeyedContainer()) != nil {
            // Decode again so the error names the bad operation.
            self.init(try [TransformOperation](from: decoder))
        } else {
            self.init([try TransformOperation(from: decoder)])
        }
    }

    public func encode(to encoder: any Encoder) throws {
        try operations.encode(to: encoder)
    }
}
