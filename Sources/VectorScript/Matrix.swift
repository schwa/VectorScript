// An affine transform: x' = a x + c y + tx, y' = b x + d y + ty (the SVG matrix(a b c d e f) layout).
public struct Matrix: Sendable, Equatable {
    public var a: Double
    public var b: Double
    public var c: Double
    public var d: Double
    public var tx: Double
    public var ty: Double

    public init(a: Double, b: Double, c: Double, d: Double, tx: Double, ty: Double) {
        self.a = a
        self.b = b
        self.c = c
        self.d = d
        self.tx = tx
        self.ty = ty
    }

    public static let identity = Matrix(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0)

    // The transform that applies `inner` first, then `outer`.
    public static func * (outer: Matrix, inner: Matrix) -> Matrix {
        Matrix(
            a: outer.a * inner.a + outer.c * inner.b,
            b: outer.b * inner.a + outer.d * inner.b,
            c: outer.a * inner.c + outer.c * inner.d,
            d: outer.b * inner.c + outer.d * inner.d,
            tx: outer.a * inner.tx + outer.c * inner.ty + outer.tx,
            ty: outer.b * inner.tx + outer.d * inner.ty + outer.ty
        )
    }

    public func applying(to point: Point) -> Point {
        Point(x: a * point.x + c * point.y + tx, y: b * point.x + d * point.y + ty)
    }
}
