import Foundation
import Testing
@testable import VectorScript

struct DocumentTests {
    @Test
    func `decodes a canvas`() throws {
        let document = try document("{ size: [256, 128], viewBox: [0, 0, 100, 50], background: '#000', elements: [] }")
        #expect(document.size == Size(width: 256, height: 128))
        #expect(document.viewBox == Rect(x: 0, y: 0, width: 100, height: 50))
        #expect(document.background == .black)
        #expect(document.version == 1)
    }

    @Test
    func `reads json5`() throws {
        let document = try document("""
        // a comment
        { size: [10, 10], /* another */ elements: [ { rect: [0, 0, 1, 1], fill: 'red', }, ], }
        """)
        #expect(document.elements.count == 1)
    }

    @Test
    func `decodes every shape`() throws {
        let document = try document(elements: """
        { rect: [1, 2, 3, 4] }, { rect: [1, 2, 3, 4], radius: 1 }, { rect: [1, 2, 3, 4], radius: [1, 2] },
        { circle: [1, 2, 3] }, { ellipse: [1, 2, 3, 4] }, { line: [1, 2, 3, 4] },
        { polyline: [[0, 0], [1, 1]] }, { polygon: [[0, 0], [1, 0], [1, 1]] }, { path: 'M 0 0 L 1 1' }
        """)
        let shapes = document.elements.map(\.content)
        #expect(shapes == [
            .shape(.rect(Rect(x: 1, y: 2, width: 3, height: 4), cornerRadius: nil)),
            .shape(.rect(Rect(x: 1, y: 2, width: 3, height: 4), cornerRadius: Size(width: 1, height: 1))),
            .shape(.rect(Rect(x: 1, y: 2, width: 3, height: 4), cornerRadius: Size(width: 1, height: 2))),
            .shape(.circle(center: Point(x: 1, y: 2), radius: 3)),
            .shape(.ellipse(center: Point(x: 1, y: 2), radii: Size(width: 3, height: 4))),
            .shape(.line(from: Point(x: 1, y: 2), to: Point(x: 3, y: 4))),
            .shape(.polyline([Point(x: 0, y: 0), Point(x: 1, y: 1)])),
            .shape(.polygon([Point(x: 0, y: 0), Point(x: 1, y: 0), Point(x: 1, y: 1)])),
            .shape(.path(PathData([.move(to: .zero), .line(to: Point(x: 1, y: 1))]))),
        ])
    }

    @Test
    func `decodes style and element properties`() throws {
        let element = try element("""
        { circle: [0, 0, 1], fill: 'red', stroke: '#00f', strokeWidth: 2, strokeCap: 'round', strokeJoin: 'bevel',
          strokeMiterLimit: 8, strokeDash: [1, 2], strokeDashOffset: 1, fillRule: 'evenodd', opacity: 0.5,
          clip: { rect: [0, 0, 1, 1] } }
        """)
        #expect(element.style == Style(fill: .color(.init(red: 1, green: 0, blue: 0)), stroke: .color(.init(red: 0, green: 0, blue: 1)), strokeWidth: 2, strokeCap: .round, strokeJoin: .bevel, strokeMiterLimit: 8, strokeDash: [1, 2], strokeDashOffset: 1, fillRule: .evenodd))
        #expect(element.opacity == 0.5)
        #expect(element.clip == Clip(.rect(Rect(x: 0, y: 0, width: 1, height: 1), cornerRadius: nil)))
    }

    @Test
    func `decodes text, groups and uses`() throws {
        let document = try document(elements: """
        { text: 'Hi', at: [1, 2], anchor: 'middle', font: 'Menlo', fontSize: 9 },
        { group: [{ circle: [0, 0, 1] }], fill: 'red' },
        { use: 'dot', at: [3, 4] }
        """, defs: "{ dot: { circle: [0, 0, 1] } }")
        #expect(document.elements[0].content == .text(Text(string: "Hi", at: Point(x: 1, y: 2), anchor: .middle)))
        #expect(document.elements[0].style.font == "Menlo")
        guard case .group(let children) = document.elements[1].content else {
            Issue.record("not a group")
            return
        }
        #expect(children.count == 1)
        #expect(document.elements[2].content == .use(Use(name: "dot", at: Point(x: 3, y: 4))))
    }

    @Test
    func `decodes gradients`() throws {
        let element = try element("""
        { rect: [0, 0, 1, 1], fill: { linearGradient: { from: [0, 0], to: [0, 1], stops: [[0, 'red'], [1, 'blue']] } },
          stroke: { radialGradient: { radius: 0.4, units: 'user', stops: [[0.5, '#fff']] } } }
        """)
        guard case .linearGradient(let linear) = element.style.fill, case .radialGradient(let radial) = element.style.stroke else {
            Issue.record("not gradients")
            return
        }
        #expect(linear.to == Point(x: 0, y: 1))
        #expect(linear.stops.count == 2)
        #expect(radial.center == Point(x: 0.5, y: 0.5))
        #expect(radial.radius == 0.4)
        #expect(radial.units == .user)
    }

    @Test(arguments: [
        ("{ circle: [0, 0, 1], fil: 'red' }", "elements[0]: unknown key 'fil'"),
        ("{ circle: [0, 0, 1], rect: [0, 0, 1, 1] }", "elements[0]: an element has more than one type key: circle, rect"),
        ("{ fill: 'red' }", "elements[0]: an element needs one of: circle, ellipse, group, image, line, path, polygon, polyline, rect, text, use"),
        ("{ circle: [0, 0] }", "elements[0].circle: expected 3 numbers, found 2"),
        ("{ circle: [0, 0, -1] }", "elements[0].circle: a radius cannot be negative"),
        ("{ circle: [0, 0, 1], radius: 2 }", "elements[0]: unknown key 'radius'"),
        ("{ circle: [0, 0, 1], opacity: 2 }", "elements[0].opacity: opacity 2 is outside 0...1"),
        ("{ rect: [0, 0, 1, 1], fill: { linearGradient: { stops: [] } } }", "elements[0].fill.linearGradient: a gradient needs at least one stop"),
        ("{ rect: [0, 0, 1, 1], fill: { linearGradient: { stops: [[2, 'red']] } } }", "elements[0].fill.linearGradient.stops[0]: stop offset 2 is outside 0...1"),
        ("{ text: 'Hi' }", "elements[0]: missing key 'at'"),
    ])
    func `strict decoding names the problem`(json: String, message: String) {
        #expect(elementFailure(json) == message)
    }

    @Test
    func `decodes text width and line height`() throws {
        let wrapped = try element("{ text: 'a\\nb', at: [0, 0], width: 80, lineHeight: 1.5 }")
        #expect(wrapped.content == .text(Text(string: "a\nb", at: .zero, width: 80)))
        #expect(wrapped.style.lineHeight == 1.5)
        #expect(elementFailure("{ text: 'a', at: [0, 0], width: 0 }") == "elements[0].width: a text width must be positive")
        let resolved = try document(elements: "{ group: [{ text: 'a', at: [0, 0] }, { rect: [0, 0, 1, 1] }], lineHeight: 2 }").resolved()
        guard case .group(let children) = resolved.elements[0].content else {
            Issue.record("not a group")
            return
        }
        #expect(children[0].style.lineHeight == 2)
        #expect(children[1].style.lineHeight == nil)
        #expect(try Document(json: resolved.jsonData()) == resolved)
    }

    @Test
    func `decodes filters`() throws {
        let single = try element("{ circle: [0, 0, 1], filter: { blur: 2 } }")
        #expect(single.filter == FilterList([.blur(2)]))
        let list = try element("{ circle: [0, 0, 1], filter: [{ dropShadow: { offset: [1, 2], blur: 3, color: '#0008' } }, { grayscale: 0.5 }, { hueRotate: -30 }] }")
        #expect(list.filter?.filters.count == 3)
        #expect(list.filter?.filters[0] == .dropShadow(offset: Point(x: 1, y: 2), blur: 3, color: Color(red: 0, green: 0, blue: 0, alpha: 136.0 / 255)))
        #expect(elementFailure("{ circle: [0, 0, 1], filter: { blur: -1 } }") == "elements[0].filter.blur: a blur radius cannot be negative")
        #expect(elementFailure("{ circle: [0, 0, 1], filter: { grayscale: 2 } }") == "elements[0].filter.grayscale: grayscale takes 0...1")
        #expect(elementFailure("{ circle: [0, 0, 1], filter: { glow: 1 } }").hasPrefix("elements[0].filter: a filter needs one of"))
        #expect(elementFailure("{ circle: [0, 0, 1], filter: { dropShadow: { spread: 1 } } }") == "elements[0].filter.dropShadow: unknown key 'spread'")
        let resolved = try document(elements: "{ group: [{ circle: [0, 0, 1] }], filter: [{ blur: 1 }, { sepia: 1 }] }").resolved()
        #expect(resolved.elements[0].filter?.filters.count == 2)
        #expect(try Document(json: resolved.jsonData()) == resolved)
    }

    @Test
    func `decodes every blend mode`() throws {
        for mode in BlendMode.allCases {
            #expect(try element("{ circle: [0, 0, 1], blendMode: '\(mode.rawValue)' }").blendMode == mode)
        }
        #expect(elementFailure("{ circle: [0, 0, 1], blendMode: 'colorDodge' }").hasPrefix("elements[0].blendMode:"))
        let resolved = try document(elements: "{ group: [{ circle: [0, 0, 1] }], blendMode: 'screen' }").resolved()
        #expect(resolved.elements[0].blendMode == .screen)
        #expect(try Document(json: resolved.jsonData()) == resolved)
    }

    @Test
    func `a bad enum value names its place`() {
        #expect(elementFailure("{ group: [{ circle: [0, 0, 1], strokeCap: 'pointy' }] }").hasPrefix("elements[0].group[0].strokeCap:"))
    }

    @Test
    func `rejects document problems`() {
        #expect(failure("{ size: [1, 1], elements: [], extra: 1 }") == "unknown key 'extra'")
        #expect(failure("{ version: 2, size: [1, 1], elements: [] }") == "unsupported version 2 (this reader knows version 1)")
        #expect(failure("{ size: [0, 1], elements: [] }") == "size: size must be positive")
        #expect(failure("{ size: [1, 1] }") == "missing key 'elements'")
        #expect(failure("{ size: [1, 1], elements: [ }").hasPrefix("malformed JSON"))
    }

    @Test
    func `accepts a schema key`() throws {
        _ = try document("{ $schema: 'vectorscript.schema.json', size: [1, 1], elements: [] }")
    }

    @Test
    func `checks references`() {
        #expect(elementFailure("{ rect: [0, 0, 1, 1], fill: '$sky' }") == "elements[0].fill: no paint named 'sky' in defs")
        #expect(elementFailure("{ use: 'dot' }") == "elements[0].use: no element named 'dot' in defs")
        #expect(elementFailure("{ use: 'sky' }", defs: "{ sky: 'red' }") == "elements[0].use: 'sky' is a paint, not an element")
        #expect(elementFailure("{ rect: [0, 0, 1, 1], fill: '$dot' }", defs: "{ dot: { circle: [0, 0, 1] } }") == "elements[0].fill: 'dot' is an element, not a paint")
        #expect(elementFailure("{ use: 'a' }", defs: "{ a: { use: 'b' }, b: { group: [{ use: 'a' }] } }").contains("use cycle"))
    }

    @Test
    func `round trips through json`() throws {
        let original = try document("""
        { size: [64, 32], viewBox: [0, 0, 10, 5], background: '#123456',
          defs: { sky: { linearGradient: { stops: [[0, 'red'], [1, '#0000ff80']] } }, dot: { circle: [0, 0, 1] }, ink: '#222' },
          elements: [
            { rect: [0, 0, 10, 5], radius: [1, 2], fill: '$sky', clip: { circle: [5, 2, 2], fillRule: 'evenodd' } },
            { group: [{ use: 'dot', at: [1, 1], fill: 'red' }, { text: 'A', at: [2, 3], anchor: 'end', fontSize: 4 }],
              stroke: '$ink', strokeDash: [1, 0.5], opacity: 0.25, transform: 'translate(1 2) rotate(30 1 1) scale(2 3) skewX(5)' },
            { path: 'M 0 0 Q 1 1 2 0 A 1 1 0 0 1 3 3 Z', fillRule: 'evenodd' },
            { polygon: [[0, 0], [1, 0], [0.5, 1]], fill: 'none' }
          ] }
        """)
        let data = try original.jsonData()
        #expect(try Document(json: data) == original)
    }
}
