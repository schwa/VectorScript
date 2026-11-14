# VectorScript

A small JSON vector graphics format, with a Swift parser, a CoreGraphics renderer and a command line tool.
It does much of what SVG does, in far less format. Path data uses the SVG path syntax.

```json5
{
  size: [256, 256],
  background: "#204060",
  defs: {
    sky: { linearGradient: { from: [0, 0], to: [0, 1], stops: [[0, "#08f"], [1, "#fff"]] } },
    bolt: { circle: [0, 0, 6], fill: "#888" }
  },
  elements: [
    { rect: [16, 16, 224, 224], radius: 12, fill: "$sky" },
    { path: "M 40 200 Q 128 40 216 200 Z", fill: "#fc0", stroke: "#000", strokeWidth: 3 },
    { use: "bolt", at: [32, 32] },
    { text: "HELLO", at: [128, 236], anchor: "middle", font: "Helvetica-Bold", fontSize: 24, fill: "#fff" }
  ]
}
```

## Package

| Product | What it is |
| --- | --- |
| `VectorScript` | The format: model types, JSON5 decoding and encoding, path and transform parsers, `resolved()`. No CoreGraphics. |
| `VectorScriptRender` | Draws documents with CoreGraphics and CoreText. Writes PNG, JPEG and PDF. |
| `vectorscript` | The command line tool. |

```swift
import VectorScript
import VectorScriptRender

let document = try Document(contentsOf: url)
let image = try Renderer(document: document).cgImage(scale: 2)
```

## Command line

```sh
vectorscript render panel.json5                    # writes panel.png
vectorscript render panel.json5 -o panel.pdf       # format from the extension
vectorscript render panel.json5 -o big.png --scale 4
vectorscript render panel.json5 --size 1024x1024   # replaces the document size
vectorscript validate *.json5                      # exits 1 on any error
vectorscript resolve panel.json5                   # prints the resolved document
```

Errors name the place in the file: `panel.json5: elements[3].fill: unknown color 'redd'`.

## Viewer

`Examples/VectorScriptViewer` is a document-based macOS and iOS app (OS 27 or later) that shows and edits
`.json5` and `.json` VectorScript files. The source is on the left and the render is on the right. The render
changes as you type. When the source has an error, the app shows the error and keeps the last good render. The
system supplies New, Open, Open Recent, one window per document, autosave, versions, and undo.

```sh
xcb build VectorScriptViewer/VectorScriptViewer
```

## Format

Files are JSON5, so comments, unquoted keys, single quotes and trailing commas are fine. Plain JSON is valid.
Parsing is strict. An unknown key, a second type key on one element, a bad value or a name that is not in
`defs` is an error. `Schema/vectorscript.schema.json` describes the format for editors.

### Document

| Key | Value |
| --- | --- |
| `version` | `1`. Optional. Other versions are rejected. |
| `size` | `[width, height]` in points. At scale 1 a point is a pixel. |
| `viewBox` | `[x, y, width, height]`: the user space that maps onto `size`. Default `[0, 0, width, height]`. Scales each axis separately. |
| `background` | A color. Default transparent. |
| `defs` | Named paints and elements. |
| `elements` | The drawing, back to front. |

Coordinates follow SVG: the origin is the top left, y points down, and angles are degrees with positive
angles turning clockwise. SVG path data and coordinates copy across unchanged.

### Elements

An element has one type key, which holds its main value.

| Element | Example |
| --- | --- |
| rect | `{ rect: [x, y, w, h] }`, with optional `radius: r` or `radius: [rx, ry]` |
| circle | `{ circle: [cx, cy, r] }` |
| ellipse | `{ ellipse: [cx, cy, rx, ry] }` |
| line | `{ line: [x1, y1, x2, y2] }` |
| polyline | `{ polyline: [[x, y], ...] }` |
| polygon | `{ polygon: [[x, y], ...] }`: a closed polyline |
| path | `{ path: "M 0 0 L 10 0 Q 15 5 10 10 Z" }`: SVG path data, `M L H V C S Q T A Z`, absolute and relative |
| group | `{ group: [elements] }` |
| use | `{ use: "name", at: [x, y] }`: draws the element called `name` in `defs` |
| text | `{ text: "Hi", at: [x, y], anchor: "middle" }`: one line. `at` is on the baseline; `anchor` is `start`, `middle` or `end` |
| image | `{ image: "wood.png", at: [x, y], size: [w, h] }`: a bitmap. See below |

Every element can also have these keys:

| Key | Value | Inherited |
| --- | --- | --- |
| `fill` | paint. Default black. | yes |
| `stroke` | paint. Default `none`. | yes |
| `strokeWidth` | number. Default 1. | yes |
| `strokeCap` | `butt`, `round`, `square` | yes |
| `strokeJoin` | `miter`, `round`, `bevel` | yes |
| `strokeMiterLimit` | number. Default 4. | yes |
| `strokeDash` | `[on, off, ...]` | yes |
| `strokeDashOffset` | number | yes |
| `fillRule` | `nonzero`, `evenodd` | yes |
| `font` | A system font's PostScript, family or full name. Default Helvetica. An unknown font is an error. | yes |
| `fontSize` | number. Default 16. | yes |
| `letterSpacing` | extra points between characters; negative tightens. Default 0. | yes |
| `opacity` | 0...1, applied to the element as a whole | no |
| `transform` | see below | no |
| `clip` | a shape: `{ circle: [...] }`, `{ path: "...", fillRule: "evenodd" }` | no |
| `mask` | `{ mode: "luminance", elements: [...] }`, see below | no |

Elements in a group take the group's inherited keys unless they set their own. A `use` passes its own style to
the definition it draws, and that style wins over the definition's style. So one definition can be drawn in
different colors.

A clip is in the element's own coordinates, after its transform. On a `use`, `at` does not move the clip.

An image's source is a path relative to the document's file, an absolute path, a `file:` URL, or a
`data:<type>;base64,<data>` URI. The renderer reads any format that ImageIO reads (PNG, JPEG, HEIC and others).
`at` is the top left corner. `size` defaults to the image's pixel size, in points. An image takes `opacity`,
`transform`, `clip` and `mask`, but no style keys. To repeat an image, put it in a pattern tile. A missing or
unreadable image is an error when the document is rendered. A document read from data (for example in the
viewer) has no file URL, so it can only use absolute paths and data URIs.

A mask is a list of elements that sets how much of the element shows. In `luminance` mode (the default), white
shows the element, black hides it, and gray shows part of it. Transparent mask content also hides the element.
In `alpha` mode only the opacity of the mask content counts. Like a clip, a mask is in the element's own
coordinates. Its elements start from the default style. Luminance is computed from sRGB values. Masks are drawn
at device resolution, and at 4 pixels per point in PDF output.

## Examples

`Examples/` has one file for each feature: `shapes`, `paths`, `fill-rules`, `strokes`, `colors`, `gradients`, `patterns`, `masks`, `images`,
`structure`, `transforms`, `clipping`, `text` and `viewbox`. It also has some textures: `brick-wall`,
`circuit-board` and `hazard-panel`.

### Paints

* A color: `#rgb`, `#rgba`, `#rrggbb`, `#rrggbbaa`, a CSS color name, or `transparent`.
* `none`.
* `"$name"`: a paint in `defs`.
* A gradient:

```json5
{ linearGradient: { from: [0, 0], to: [1, 0], stops: [[0, "red"], [1, "blue"]] } }
{ radialGradient: { center: [0.5, 0.5], radius: 0.5, focus: [0.3, 0.3], stops: [[0, "#fff"], [1, "#fff0"]] } }
```

Gradient coordinates are fractions of the shape's bounding box. With `units: "user"` they are user space
coordinates instead. Each stop is `[offset, color]`, with the offset in 0...1.

* A pattern: a tile of elements that repeats.

```json5
{ pattern: { size: [20, 20], transform: "rotate(45)", elements: [
    { rect: [0, 0, 20, 20], fill: "#fc3" },
    { rect: [0, 0, 20, 10], fill: "#222" }
] } }
```

The tile covers `[0, 0, width, height]` in the painted shape's user space, and its `transform` moves the tile.
Anything outside the tile is clipped off. The elements in a tile start from the default style: they do not inherit
from the shape that is painted. A pattern cannot use itself. Bitmaps draw the tiles on a pixel grid, so rotated
tiles meet without seams. PDF output keeps the tiles as vectors.

### Transforms

Three forms, which all mean the same thing:

```json5
transform: "translate(128 128) rotate(45) scale(2)"
transform: [{ translate: [128, 128] }, { rotate: 45 }, { scale: 2 }]
transform: { rotate: 45 }
```

The operations are `translate: [x, y]`, `rotate: degrees` or `rotate: [degrees, cx, cy]`, `scale: s` or
`scale: [sx, sy]`, `skewX: degrees`, `skewY: degrees` and `matrix: [a, b, c, d, e, f]`. As in SVG, the first
operation is the outermost one. A `use` places its definition at `at` after its own transform.

### Resolved documents

`document.resolved()` gives the same drawing with nothing left to look up:

* every shape and text has its full style,
* `$name` paints and `use` elements are replaced by what they name,
* each transform is one matrix,
* groups have no style.

A resolved document is still a valid VectorScript document, and it encodes to JSON like any other. It is the
level that other formats can lower to. The renderer draws resolved documents, and it resolves any document
that is not resolved yet.

## Development

```sh
xcb build
xcb test
```

Render tests compare against the PNGs in `Tests/GoldenImages`. Each case is a file in `Tests/Goldens`. When a
golden is missing or does not match, the test writes the new render to `$TMPDIR/GoldenImages`. To accept a
render, check it and then copy it into `Tests/GoldenImages`. The schema test runs `uvx check-jsonschema`, and it
is skipped when `uvx` is not installed.

Work is tracked in `ISSUES.md` with the `issues` tool, in the milestones `v1` and `later`.
