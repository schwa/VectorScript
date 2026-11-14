extension Document {
    // Checks that every "$name" and "use" names a definition of the right kind, and that uses and patterns do not
    // loop.
    public func validateReferences() throws(DocumentError) {
        for (index, element) in elements.enumerated() {
            try validate(element, path: "elements[\(index)]", useStack: [], paintStack: [])
        }
        for name in defs.keys.sorted() {
            switch defs[name] {
            case .element(let element):
                try validate(element, path: "defs.\(name)", useStack: [name], paintStack: [])
            case .paint(let paint):
                try validate(paint, path: "defs.\(name)", paintStack: [name])
            case nil:
                break
            }
        }
    }

    private func validate(_ element: Element, path: String, useStack: [String], paintStack: [String]) throws(DocumentError) {
        if let fill = element.style.fill {
            try validate(fill, path: "\(path).fill", paintStack: paintStack)
        }
        if let stroke = element.style.stroke {
            try validate(stroke, path: "\(path).stroke", paintStack: paintStack)
        }
        for (index, child) in (element.mask?.elements ?? []).enumerated() {
            try validate(child, path: "\(path).mask.elements[\(index)]", useStack: useStack, paintStack: paintStack)
        }
        switch element.content {
        case .shape, .text:
            break
        case .group(let children):
            for (index, child) in children.enumerated() {
                try validate(child, path: "\(path).group[\(index)]", useStack: useStack, paintStack: paintStack)
            }
        case .use(let use):
            switch defs[use.name] {
            case .element(let definition):
                guard !useStack.contains(use.name) else {
                    throw .invalid(path: "\(path).use", message: "use cycle: \((useStack + [use.name]).joined(separator: " -> "))")
                }
                // Only definitions are followed, so each one is checked once per chain.
                if !useStack.isEmpty {
                    try validate(definition, path: "defs.\(use.name)", useStack: useStack + [use.name], paintStack: paintStack)
                }
            case .paint:
                throw .invalid(path: "\(path).use", message: "'\(use.name)' is a paint, not an element")
            case nil:
                throw .invalid(path: "\(path).use", message: "no element named '\(use.name)' in defs")
            }
        }
    }

    private func validate(_ paint: Paint, path: String, paintStack: [String]) throws(DocumentError) {
        switch paint {
        case .reference(let name):
            switch defs[name] {
            case .paint(let definition):
                guard !paintStack.contains(name) else {
                    throw .invalid(path: path, message: "pattern cycle: \((paintStack + [name]).joined(separator: " -> "))")
                }
                if !paintStack.isEmpty {
                    try validate(definition, path: "defs.\(name)", paintStack: paintStack + [name])
                }
            case .element:
                throw .invalid(path: path, message: "'\(name)' is an element, not a paint")
            case nil:
                throw .invalid(path: path, message: "no paint named '\(name)' in defs")
            }
        case .pattern(let pattern):
            for (index, element) in pattern.elements.enumerated() {
                try validate(element, path: "\(path).pattern.elements[\(index)]", useStack: [], paintStack: paintStack)
            }
        case .none, .color, .linearGradient, .radialGradient:
            break
        }
    }
}
