import Foundation

// A document's JSON, kept so it can be read again at any time in its animation. Reading evaluates the
// expressions, so each time gives its own `Document`.
public struct DocumentSource: Sendable {
    public var json: Data
    public var baseURL: URL?
    public var parameters: [String: ParameterValue]
    // Read once to check the JSON and to find the animation.
    public let animation: Animation?

    public init(json: Data, baseURL: URL? = nil, parameters: [String: ParameterValue] = [:]) throws {
        self.json = json
        self.baseURL = baseURL
        self.parameters = parameters
        animation = try Document(json: json, baseURL: baseURL, parameters: parameters).animation
    }

    public init(contentsOf url: URL, parameters: [String: ParameterValue] = [:]) throws {
        try self.init(json: try Data(contentsOf: url), baseURL: url, parameters: parameters)
    }

    public func document(at time: Double = 0) throws -> Document {
        try Document(json: json, baseURL: baseURL, parameters: parameters, time: time)
    }
}
