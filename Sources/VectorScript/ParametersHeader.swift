// Reads only a document's "parameters" block, before the rest is decoded with the evaluated values.
// Each value is a number, a "#" color, or an expression string.
struct ParametersHeader: Decodable {
    var parameters: [String: ParameterValue]

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: AnyKey.self)
        guard container.contains(AnyKey("parameters")) else {
            parameters = [:]
            return
        }
        let block = try container.nestedContainer(keyedBy: AnyKey.self, forKey: AnyKey("parameters"))
        var parameters: [String: ParameterValue] = [:]
        for key in block.allKeys {
            guard key.stringValue.first?.isLetter == true || key.stringValue.first == "_", key.stringValue.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: block.codingPath + [key], debugDescription: "a parameter name is letters, digits and _, starting with a letter or _"))
            }
            if let number = try? block.decode(Double.self, forKey: key) {
                parameters[key.stringValue] = .number(number)
                continue
            }
            let text = try block.decode(String.self, forKey: key)
            if text.hasPrefix("#") {
                do {
                    parameters[key.stringValue] = .color(try Color(parsing: text))
                } catch {
                    throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: block.codingPath + [key], debugDescription: error.description))
                }
            } else {
                parameters[key.stringValue] = .expression(text)
            }
        }
        self.parameters = parameters
    }
}
