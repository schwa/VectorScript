import CoreGraphics

// The info object behind a CGPattern. CoreGraphics calls back through C, so errors are kept here for the caller.
final class PatternCell: @unchecked Sendable {
    private let body: (CGContext) throws -> Void
    private(set) var error: (any Error)?

    init(_ body: @escaping (CGContext) throws -> Void) {
        self.body = body
    }

    func draw(in context: CGContext) {
        guard error == nil else {
            return
        }
        do {
            try body(context)
        } catch {
            self.error = error
        }
    }
}
