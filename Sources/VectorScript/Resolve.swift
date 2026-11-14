extension Document {
    // The same drawing with nothing left to look up: every shape and text carries its full style, "$name" paints
    // and uses are replaced by what they name, and each transform is one matrix. The result is a valid document.
    public func resolved() throws(DocumentError) -> Document {
        try validateReferences()
        var result = self
        result.defs = [:]
        result.elements = try elements.map { element throws(DocumentError) in
            try resolve(element, inherited: .initial, overrides: Style())
        }
        return result
    }

    // `overrides` is the style of a "use" that is drawing this element; it wins over the element's own style.
    private func resolve(_ element: Element, inherited: Style, overrides: Style) throws(DocumentError) -> Element {
        let own = overrides.merged(over: element.style)
        var effective = own.merged(over: inherited)
        effective.fill = try resolve(effective.fill)
        effective.stroke = try resolve(effective.stroke)
        let transform = element.transform.map { Transform(matrix: $0.matrix) }

        switch element.content {
        case .shape:
            effective.font = nil
            effective.fontSize = nil
            return Element(element.content, style: effective, opacity: element.opacity, transform: transform, clip: element.clip)
        case .text:
            return Element(element.content, style: effective, opacity: element.opacity, transform: transform, clip: element.clip)
        case .group(let children):
            let resolvedChildren = try children.map { child throws(DocumentError) in
                try resolve(child, inherited: effective, overrides: Style())
            }
            return Element(.group(resolvedChildren), opacity: element.opacity, transform: transform, clip: element.clip)
        case .use(let use):
            guard case .element(let definition) = defs[use.name] else {
                throw .invalid(path: "", message: "no element named '\(use.name)' in defs")
            }
            var child = try resolve(definition, inherited: inherited, overrides: own)
            // `at` places the definition; the use's clip stays in the use's own space, outside that placement.
            if let at = use.at, at != .zero {
                child = Element(.group([child]), transform: Transform(matrix: TransformOperation.translate(x: at.x, y: at.y).matrix))
            }
            return Element(.group([child]), opacity: element.opacity, transform: transform, clip: element.clip)
        }
    }

    private func resolve(_ paint: Paint?) throws(DocumentError) -> Paint? {
        guard case .reference(let name) = paint else {
            return paint
        }
        guard case .paint(let definition) = defs[name] else {
            throw .invalid(path: "", message: "no paint named '\(name)' in defs")
        }
        return definition
    }

    public var isResolved: Bool {
        (try? checkResolved()) != nil
    }

    // Throws when the document still needs `resolved()`: a renderer draws only resolved documents.
    public func checkResolved() throws(DocumentError) {
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
        let style = element.style
        switch element.content {
        case .use:
            throw fail("use")
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
                if case .reference = paint {
                    throw fail("paint is a reference")
                }
            }
            if case .text = element.content {
                guard style.font != nil, style.fontSize != nil else {
                    throw fail("text has no font")
                }
            }
        }
    }
}
