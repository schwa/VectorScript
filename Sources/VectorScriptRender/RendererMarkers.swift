import CoreGraphics
import VectorScript

extension Renderer {
    // Markers draw after the shape's fill and stroke, each with its origin on a vertex.
    func drawMarkers(on shape: Shape, style: Style, in context: CGContext) throws {
        guard shape.takesMarkers, style.markerStart != nil || style.markerMid != nil || style.markerEnd != nil else {
            return
        }
        for vertex in shape.markerVertices {
            let marker: Marker? = switch vertex.position {
            case .start: style.markerStart
            case .mid: style.markerMid
            case .end: style.markerEnd
            }
            guard let marker, case .element(let content) = marker.source else {
                continue
            }
            let degrees: Double = switch marker.orientation {
            case .auto: vertex.angle
            case .autoStartReverse: vertex.position == .start ? vertex.angle + 180 : vertex.angle
            case .angle(let fixed): fixed
            }
            context.saveGState()
            context.translateBy(x: vertex.point.x, y: vertex.point.y)
            context.rotate(by: degrees * .pi / 180)
            try draw(content, in: context)
            context.restoreGState()
        }
    }
}
