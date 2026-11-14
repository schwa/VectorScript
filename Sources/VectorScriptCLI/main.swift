import ArgumentParser
import Foundation
import VectorScript
import VectorScriptRender

struct VectorScriptCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "vectorscript",
        abstract: "Render and check VectorScript JSON vector graphics.",
        subcommands: [Render.self, Validate.self, Resolve.self]
    )
}

struct OutputSize: ExpressibleByArgument {
    var size: Size

    init?(argument: String) {
        let parts = argument.lowercased().split(separator: "x")
        guard parts.count == 2, let width = Double(parts[0]), let height = Double(parts[1]), width > 0, height > 0 else {
            return nil
        }
        size = Size(width: width, height: height)
    }
}

extension OutputFormat: ExpressibleByArgument {}

struct Failure: Error, CustomStringConvertible {
    var description: String
}

// --set NAME=VALUE, where VALUE is a number, a "#" color, or an expression.
struct ParameterOptions: ParsableArguments {
    @Option(name: .customLong("set"), help: ArgumentHelp("Set a document parameter: NAME=VALUE, where VALUE is a number, a #color or an expression. Repeatable.", valueName: "name=value"))
    var assignments: [String] = []

    func parameters() throws -> [String: ParameterValue] {
        var result: [String: ParameterValue] = [:]
        for assignment in assignments {
            guard let equals = assignment.firstIndex(of: "="), equals != assignment.startIndex else {
                throw Failure(description: "--set \(assignment): expected NAME=VALUE")
            }
            let name = String(assignment[..<equals])
            do {
                result[name] = try ParameterValue(parsing: String(assignment[assignment.index(after: equals)...]))
            } catch {
                throw Failure(description: "--set \(assignment): \(error)")
            }
        }
        return result
    }
}

func load(_ path: String, parameters: ParameterOptions = ParameterOptions()) throws -> Document {
    let values = try parameters.parameters()
    do {
        return try Document(contentsOf: URL(filePath: path), parameters: values)
    } catch let error as DocumentError {
        throw Failure(description: "\(path): \(error)")
    } catch {
        throw Failure(description: "\(path): \(error.localizedDescription)")
    }
}

struct Render: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Render a document to PNG, JPEG or PDF.")

    @Argument(help: "The input .json or .json5 file.")
    var input: String

    @Option(name: .shortAndLong, help: "Output file. Default: the input with the format's extension.")
    var output: String?

    @Option(help: "Output format: png, jpeg or pdf. Default: from the output extension, else png.")
    var format: OutputFormat?

    @Option(help: "Pixels per point (bitmap formats).")
    var scale: Double = 1

    @Option(help: "Output size WIDTHxHEIGHT in points, replacing the document size.")
    var size: OutputSize?

    @OptionGroup var parameters: ParameterOptions

    func run() throws {
        let document = try load(input, parameters: parameters)
        let outputURL: URL
        let resolvedFormat: OutputFormat
        if let output {
            outputURL = URL(filePath: output)
            if let format {
                resolvedFormat = format
            } else if let inferred = OutputFormat(pathExtension: outputURL.pathExtension) {
                resolvedFormat = inferred
            } else {
                throw Failure(description: "cannot tell the format of '\(output)'; use --format")
            }
        } else {
            resolvedFormat = format ?? .png
            outputURL = URL(filePath: input).deletingPathExtension().appendingPathExtension(resolvedFormat.pathExtension)
        }
        guard scale > 0 else {
            throw Failure(description: "--scale must be positive")
        }
        do {
            try Renderer(document: document).write(to: outputURL, format: resolvedFormat, size: size?.size, scale: scale)
        } catch {
            throw Failure(description: "\(input): \(error)")
        }
        print(outputURL.path)
    }
}

struct Validate: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Check documents without rendering them.")

    @Argument(help: "Input files.")
    var inputs: [String]

    @OptionGroup var parameters: ParameterOptions

    func run() throws {
        var failed = false
        for input in inputs {
            do {
                _ = try load(input, parameters: parameters).resolved()
                print("\(input): ok")
            } catch {
                FileHandle.standardError.write(Data("\(error)\n".utf8))
                failed = true
            }
        }
        if failed {
            throw ExitCode.failure
        }
    }
}

struct Resolve: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Print the resolved form of a document as JSON.")

    @Argument(help: "The input file.")
    var input: String

    @Flag(help: "Keep uses as shared instances of resolved definitions instead of expanding them.")
    var instances = false

    @OptionGroup var parameters: ParameterOptions

    func run() throws {
        let data = try load(input, parameters: parameters).resolved(keepingInstances: instances).jsonData()
        print(String(decoding: data, as: UTF8.self))
    }
}

do {
    var command = try VectorScriptCommand.parseAsRoot()
    try command.run()
} catch let failure as Failure {
    FileHandle.standardError.write(Data("error: \(failure.description)\n".utf8))
    exit(1)
} catch {
    VectorScriptCommand.exit(withError: error)
}
