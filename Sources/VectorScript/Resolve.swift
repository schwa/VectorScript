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
        var mask = element.mask
        if let elements = mask?.elements {
            // Mask contents start from the initial style, not from the masked element.
            mask?.elements = try elements.map { child throws(DocumentError) in
                try resolve(child, inherited: .initial, overrides: Style())
            }
        }

        switch element.content {
        case .shape:
            effective.font = nil
            effective.fontSize = nil
            effective.letterSpacing = nil
            return Element(element.content, style: effective, opacity: element.opacity, transform: transform, clip: element.clip, mask: mask, blendMode: element.blendMode)
        case .text:
            return Element(element.content, style: effective, opacity: element.opacity, transform: transform, clip: element.clip, mask: mask, blendMode: element.blendMode)
        case .image:
            // Images do not use fill or stroke.
            return Element(element.content, opacity: element.opacity, transform: transform, clip: element.clip, mask: mask, blendMode: element.blendMode)
        case .group(let children):
            let resolvedChildren = try children.map { child throws(DocumentError) in
                try resolve(child, inherited: effective, overrides: Style())
            }
            return Element(.group(resolvedChildren), opacity: element.opacity, transform: transform, clip: element.clip, mask: mask, blendMode: element.blendMode)
        case .use(let use):
            guard case .element(let definition) = defs[use.name] else {
                throw .invalid(path: "", message: "no element named '\(use.name)' in defs")
            }
            var child = try resolve(definition, inherited: inherited, overrides: own)
            // `at` places the definition; the use's clip stays in the use's own space, outside that placement.
            if let at = use.at, at != .zero {
                child = Element(.group([child]), transform: Transform(matrix: TransformOperation.translate(x: at.x, y: at.y).matrix))
            }
            return Element(.group([child]), opacity: element.opacity, transform: transform, clip: element.clip, mask: mask, blendMode: element.blendMode)
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
        for (index, child) in (element.mask?.elements ?? []).enumerated() {
            try checkResolved(child, path: "\(path).mask.elements[\(index)]")
        }
        let style = element.style
        switch element.content {
        case .use:
            throw fail("use")
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
            if case .text = element.content {
                guard style.font != nil, style.fontSize != nil else {
                    throw fail("text has no font")
                }
            }
        }
    }
}
