extension Document {
    // The same drawing with nothing left to look up: every shape and text carries its full style, "$name" paints
    // are replaced by what they name, and each transform is one matrix. The result is a valid document.
    //
    // By default every use is expanded in place. With `keepingInstances`, each use instead names a resolved
    // definition in the result's defs, and uses whose definitions resolve the same way share one. A definition
    // that resolves differently at different uses (because of style overrides or inheritance) gets one entry per
    // way: "dot", "dot-2", and so on.
    public func resolved(keepingInstances: Bool = false) throws(DocumentError) -> Document {
        try validateReferences()
        let resolver = Resolver(document: self, keepingInstances: keepingInstances)
        var result = self
        result.elements = try elements.map { element throws(DocumentError) in
            try resolver.resolve(element, inherited: .initial, overrides: Style())
        }
        result.defs = Dictionary(uniqueKeysWithValues: resolver.instances.map { ($0.name, Definition.element($0.element)) })
        return result
    }

    public var isResolved: Bool {
        (try? checkResolved()) != nil
    }

    // Throws when the document still needs `resolved()`: a renderer draws only resolved documents. Defs may hold
    // only resolved elements, for uses to draw.
    public func checkResolved() throws(DocumentError) {
        for name in defs.keys.sorted() {
            guard case .element(let element) = defs[name] else {
                throw .invalid(path: "defs.\(name)", message: "not resolved: a paint in defs")
            }
            try checkResolved(element, path: "defs.\(name)")
        }
        for (index, element) in elements.enumerated() {
            try checkResolved(element, path: "elements[\(index)]")
        }
    }

    private func checkResolved(_ element: Element, path: String) throws(DocumentError) {
        func fail(_ message: String) -> DocumentError {
            .invalid(path: path, message: "not resolved: \(message)")
        }
        if let transform = element.transform {
            guard transform.operations.count == 1, case .matrix = transform.operations[0] else {
                throw fail("transform is not one matrix")
            }
        }
        for (index, child) in (element.mask?.elements ?? []).enumerated() {
            try checkResolved(child, path: "\(path).mask.elements[\(index)]")
        }
        let style = element.style
        switch element.content {
        case .use(let use):
            guard style.isEmpty else {
                throw fail("a use has style")
            }
            guard case .element = defs[use.name] else {
                throw fail("use of '\(use.name)', which is not in defs")
            }
        case .image:
            break
        case .group(let children):
            guard style.isEmpty else {
                throw fail("a group has style")
            }
            for (index, child) in children.enumerated() {
                try checkResolved(child, path: "\(path).group[\(index)]")
            }
        case .shape, .text:
            guard let fill = style.fill, let stroke = style.stroke, style.strokeWidth != nil, style.strokeCap != nil, style.strokeJoin != nil, style.strokeMiterLimit != nil, style.strokeDash != nil, style.strokeDashOffset != nil, style.fillRule != nil else {
                throw fail("style is incomplete")
            }
            for paint in [fill, stroke] {
                switch paint {
                case .reference:
                    throw fail("paint is a reference")
                case .pattern(let pattern):
                    if let transform = pattern.transform {
                        guard transform.operations.count == 1, case .matrix = transform.operations[0] else {
                            throw fail("pattern transform is not one matrix")
                        }
                    }
                    for (index, child) in pattern.elements.enumerated() {
                        try checkResolved(child, path: "\(path).pattern.elements[\(index)]")
                    }
                default:
                    break
                }
            }
            for marker in [style.markerStart, style.markerMid, style.markerEnd].compactMap(\.self) {
                guard case .element(let content) = marker.source else {
                    throw fail("marker is not inline")
                }
                try checkResolved(content, path: "\(path).marker")
            }
            if case .text = element.content {
                guard style.font != nil, style.fontSize != nil else {
                    throw fail("text has no font")
                }
            }
        }
    }
}

// One resolve pass. Holds the instances collected when keeping them.
private final class Resolver {
    let document: Document
    let keepingInstances: Bool
    // In order of first use, so the output is stable.
    private(set) var instances: [(name: String, element: Element)] = []

    init(document: Document, keepingInstances: Bool) {
        self.document = document
        self.keepingInstances = keepingInstances
    }

    var defs: [String: Definition] {
        document.defs
    }

    // `overrides` is the style of a "use" that is drawing this element; it wins over the element's own style.
    func resolve(_ element: Element, inherited: Style, overrides: Style) throws(DocumentError) -> Element {
        let own = overrides.merged(over: element.style)
        var effective = own.merged(over: inherited)
        effective.fill = try resolve(effective.fill)
        effective.stroke = try resolve(effective.stroke)
        let transform = element.transform.map { Transform(matrix: $0.matrix) }
        var mask = element.mask
        if let elements = mask?.elements {
            // Mask contents start from the initial style, not from the masked element.
            mask?.elements = try elements.map { child throws(DocumentError) in
                try resolve(child, inherited: .initial, overrides: Style())
            }
        }

        // The element with new content and style. Element-wide properties (opacity, clip, blend mode, filter) carry
        // over as they are.
        func resolved(_ content: Element.Content, style: Style) -> Element {
            var result = element
            result.content = content
            result.style = style
            result.transform = transform
            result.mask = mask
            return result
        }

        switch element.content {
        case .shape(let shape):
            if shape.takesMarkers {
                effective.markerStart = try resolve(effective.markerStart)
                effective.markerMid = try resolve(effective.markerMid)
                effective.markerEnd = try resolve(effective.markerEnd)
            } else {
                effective.markerStart = nil
                effective.markerMid = nil
                effective.markerEnd = nil
            }
            effective.font = nil
            effective.fontSize = nil
            effective.letterSpacing = nil
            effective.fontFile = nil
            effective.lineHeight = nil
            return resolved(element.content, style: effective)
        case .text:
            effective.markerStart = nil
            effective.markerMid = nil
            effective.markerEnd = nil
            return resolved(element.content, style: effective)
        case .image:
            // Images do not use fill or stroke.
            return resolved(element.content, style: Style())
        case .group(let children):
            let resolvedChildren = try children.map { child throws(DocumentError) in
                try resolve(child, inherited: effective, overrides: Style())
            }
            return resolved(.group(resolvedChildren), style: Style())
        case .use(let use):
            guard case .element(let definition) = defs[use.name] else {
                throw .invalid(path: "", message: "no element named '\(use.name)' in defs")
            }
            var child = try resolve(definition, inherited: inherited, overrides: own)
            if keepingInstances {
                return resolved(.use(Use(name: instanceName(for: child, definition: use.name), at: use.at)), style: Style())
            }
            // `at` places the definition; the use's clip stays in the use's own space, outside that placement.
            if let at = use.at, at != .zero {
                child = Element(.group([child]), transform: Transform(matrix: TransformOperation.translate(x: at.x, y: at.y).matrix))
            }
            return resolved(.group([child]), style: Style())
        }
    }

    // The existing instance that matches `element`, or a new one named after its definition.
    private func instanceName(for element: Element, definition: String) -> String {
        if let match = instances.first(where: { $0.element == element }) {
            return match.name
        }
        var name = definition
        var suffix = 2
        while instances.contains(where: { $0.name == name }) {
            name = "\(definition)-\(suffix)"
            suffix += 1
        }
        instances.append((name, element))
        return name
    }

    // Marker contents start from the initial style, not from the marked shape.
    private func resolve(_ marker: Marker?) throws(DocumentError) -> Marker? {
        guard let marker else {
            return nil
        }
        switch marker.source {
        case .none:
            return nil
        case .element(let element):
            return Marker(.element(try resolve(element, inherited: .initial, overrides: Style())), orientation: marker.orientation)
        case .named(let name):
            guard case .element(let definition) = defs[name] else {
                throw .invalid(path: "", message: "no element named '\(name)' in defs")
            }
            return Marker(.element(try resolve(definition, inherited: .initial, overrides: Style())), orientation: marker.orientation)
        }
    }

    private func resolve(_ paint: Paint?) throws(DocumentError) -> Paint? {
        switch paint {
        case .reference(let name):
            guard case .paint(let definition) = defs[name] else {
                throw .invalid(path: "", message: "no paint named '\(name)' in defs")
            }
            return try resolve(definition)
        case .pattern(var pattern):
            // Pattern contents start from the initial style, not from the element being painted.
            pattern.elements = try pattern.elements.map { element throws(DocumentError) in
                try resolve(element, inherited: .initial, overrides: Style())
            }
            pattern.transform = pattern.transform.map { Transform(matrix: $0.matrix) }
            return .pattern(pattern)
        default:
            return paint
        }
    }
}
