extension Document {
    // Checks that every "$name" and "use" names a definition of the right kind, and that uses do not loop.
    public func validateReferences() throws(DocumentError) {
        for (index, element) in elements.enumerated() {
            try validate(element, path: "elements[\(index)]", useStack: [])
        }
        for name in defs.keys.sorted() {
            if case .element(let element) = defs[name] {
                try validate(element, path: "defs.\(name)", useStack: [name])
            }
        }
    }

    private func validate(_ element: Element, path: String, useStack: [String]) throws(DocumentError) {
        try validate(element.style.fill, path: "\(path).fill")
        try validate(element.style.stroke, path: "\(path).stroke")
        switch element.content {
        case .shape, .text:
            break
        case .group(let children):
            for (index, child) in children.enumerated() {
                try validate(child, path: "\(path).group[\(index)]", useStack: useStack)
            }
        case .use(let use):
            switch defs[use.name] {
            case .element(let definition):
                guard !useStack.contains(use.name) else {
                    throw .invalid(path: "\(path).use", message: "use cycle: \((useStack + [use.name]).joined(separator: " -> "))")
                }
                // Only definitions are followed, so each one is checked once per chain.
                if !useStack.isEmpty {
                    try validate(definition, path: "defs.\(use.name)", useStack: useStack + [use.name])
                }
            case .paint:
                throw .invalid(path: "\(path).use", message: "'\(use.name)' is a paint, not an element")
            case nil:
                throw .invalid(path: "\(path).use", message: "no element named '\(use.name)' in defs")
            }
        }
    }

    private func validate(_ paint: Paint?, path: String) throws(DocumentError) {
        guard case .reference(let name) = paint else {
            return
        }
        switch defs[name] {
        case .paint:
            break
        case .element:
            throw .invalid(path: path, message: "'\(name)' is an element, not a paint")
        case nil:
            throw .invalid(path: path, message: "no paint named '\(name)' in defs")
        }
    }
}
