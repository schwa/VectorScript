# ISSUES.md

File format: <https://github.com/schwa/issues-format>

---

## 1: No document model

+++
status: closed
priority: medium
kind: feature
milestone: v1
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:51:31Z
closed: 2026-11-14T19:51:31Z
+++

There are no public Swift types for a VectorScript document: canvas (size, optional viewBox, background), version, defs and elements. Types must be public, Sendable, Equatable, have memberwise initialisers, and must not import CoreGraphics.

- `2026-11-14T19:51:31Z`: Implemented in the initial v1 commit.

---

## 2: No strict JSON5 decoding

+++
status: closed
priority: medium
kind: feature
milestone: v1
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:51:31Z
closed: 2026-11-14T19:51:31Z
+++

Documents cannot be read from JSON5. Decoding must be strict: unknown keys, more than one type key on an element, and unknown versions are errors. Error messages must name the coding path, for example elements[3].fill.

- `2026-11-14T19:51:31Z`: Implemented in the initial v1 commit.

---

## 3: No JSON encoding of documents

+++
status: closed
priority: medium
kind: feature
milestone: v1
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:51:31Z
closed: 2026-11-14T19:51:31Z
+++

Documents cannot be written back to JSON. Decode then encode then decode must give an equal document.

- `2026-11-14T19:51:31Z`: Implemented in the initial v1 commit.

---

## 4: No basic shapes

+++
status: closed
priority: medium
kind: feature
milestone: v1
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:51:31Z
closed: 2026-11-14T19:51:31Z
+++

Missing elements: rect (with corner radius), circle, ellipse, line, polyline, polygon. Elements are keyed by type with compact array arguments, for example { circle: [cx, cy, r] }.

- `2026-11-14T19:51:31Z`: Implemented in the initial v1 commit.

---

## 5: No path element

+++
status: closed
priority: medium
kind: feature
milestone: v1
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:51:31Z
closed: 2026-11-14T19:51:31Z
+++

Missing the path element, which takes SVG path data: M L H V C S Q T A Z in absolute and relative forms, implicit repeats, SVG number syntax (1-2, .5.5) and arc flags.

- `2026-11-14T19:51:31Z`: Implemented in the initial v1 commit.

---

## 6: No groups

+++
status: closed
priority: medium
kind: feature
milestone: v1
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:51:31Z
closed: 2026-11-14T19:51:31Z
+++

Missing the group element: { group: [elements], ... } with its own style, opacity, transform and clip.

- `2026-11-14T19:51:31Z`: Implemented in the initial v1 commit.

---

## 7: No transforms

+++
status: closed
priority: medium
kind: feature
milestone: v1
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:51:31Z
closed: 2026-11-14T19:51:31Z
+++

Missing transform on elements. Forms: an SVG transform string, an ordered array of single-operation objects, or one operation object. Operations: translate, rotate (optional centre), scale, skewX, skewY, matrix. Order follows SVG.

- `2026-11-14T19:51:31Z`: Implemented in the initial v1 commit.

---

## 8: No colour parsing

+++
status: closed
priority: medium
kind: feature
milestone: v1
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:51:31Z
closed: 2026-11-14T19:51:31Z
+++

Missing colour values: #rgb, #rgba, #rrggbb, #rrggbbaa, CSS named colours and none. Unknown colours are errors.

- `2026-11-14T19:51:31Z`: Implemented in the initial v1 commit.

---

## 9: No gradients

+++
status: closed
priority: medium
kind: feature
milestone: v1
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:51:31Z
closed: 2026-11-14T19:51:31Z
+++

Missing linearGradient and radialGradient paints, written inline or in defs. Stops are [offset, colour] pairs. Coordinates are relative to the shape bounding box by default; units: user makes them absolute.

- `2026-11-14T19:51:31Z`: Implemented in the initial v1 commit.

---

## 10: No defs, use or $name references

+++
status: closed
priority: medium
kind: feature
milestone: v1
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:51:31Z
closed: 2026-11-14T19:51:31Z
+++

Missing defs (one flat namespace of paints and elements), use (name, optional at, transform, style overrides) and $name paint references. Unresolved references and use cycles are errors.

- `2026-11-14T19:51:31Z`: Implemented in the initial v1 commit.

---

## 11: No style inheritance

+++
status: closed
priority: medium
kind: feature
milestone: v1
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:51:31Z
closed: 2026-11-14T19:51:31Z
+++

fill, stroke, stroke properties, fillRule and font properties do not inherit from groups. opacity, transform and clip must not inherit. Defaults: fill black, stroke none.

- `2026-11-14T19:51:31Z`: Implemented in the initial v1 commit.

---

## 12: No stroke properties

+++
status: closed
priority: medium
kind: feature
milestone: v1
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:51:31Z
closed: 2026-11-14T19:51:31Z
+++

Missing strokeWidth, strokeCap, strokeJoin, strokeMiterLimit, strokeDash and strokeDashOffset.

- `2026-11-14T19:51:31Z`: Implemented in the initial v1 commit.

---

## 13: No fill rule

+++
status: closed
priority: medium
kind: feature
milestone: v1
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:51:31Z
closed: 2026-11-14T19:51:31Z
+++

Missing fillRule: nonzero or evenodd.

- `2026-11-14T19:51:31Z`: Implemented in the initial v1 commit.

---

## 14: No opacity

+++
status: closed
priority: medium
kind: feature
milestone: v1
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:51:31Z
closed: 2026-11-14T19:51:31Z
+++

Missing opacity on elements and groups. Group opacity applies to the group as a whole.

- `2026-11-14T19:51:31Z`: Implemented in the initial v1 commit.

---

## 15: No clipping

+++
status: closed
priority: medium
kind: feature
milestone: v1
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:51:31Z
closed: 2026-11-14T19:51:31Z
+++

Missing clip on elements and groups, taking a shape or path.

- `2026-11-14T19:51:31Z`: Implemented in the initial v1 commit.

---

## 16: No text element

+++
status: closed
priority: medium
kind: feature
milestone: v1
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:51:31Z
closed: 2026-11-14T19:51:31Z
+++

Missing single-line text: { text, at, font, fontSize, anchor }. at is the baseline origin. anchor is start, middle or end. Fonts come from the system; an unknown font is an error. Text fills, strokes and clips like a path.

- `2026-11-14T19:51:31Z`: Implemented in the initial v1 commit.

---

## 17: No resolve pass

+++
status: closed
priority: medium
kind: feature
milestone: v1
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:51:31Z
closed: 2026-11-14T19:51:31Z
+++

There is no way to turn an authored document into a resolved one. A resolved document is valid VectorScript with explicit styles, no references, use expanded and transforms as matrices. resolve() must be pure and live in the portable target.

- `2026-11-14T19:51:31Z`: Implemented in the initial v1 commit.

---

## 18: No CoreGraphics renderer

+++
status: closed
priority: medium
kind: feature
milestone: v1
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:51:32Z
closed: 2026-11-14T19:51:32Z
+++

Resolved documents cannot be drawn. Missing a VectorScriptRender target that draws into a CGContext and produces CGImage, PNG, JPEG and PDF, with a scale factor and size override.

- `2026-11-14T19:51:32Z`: Implemented in the initial v1 commit.

---

## 19: No command line tool

+++
status: closed
priority: medium
kind: feature
milestone: v1
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:51:32Z
closed: 2026-11-14T19:51:32Z
+++

Missing the vectorscript executable: render input [-o output] [--scale] [--size WxH] [--format png|pdf|jpeg], and validate input. Format is inferred from the output extension. Errors name the coding path and exit non-zero.

- `2026-11-14T19:51:32Z`: Implemented in the initial v1 commit.

---

## 20: No JSON Schema

+++
status: closed
priority: medium
kind: feature
milestone: v1
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:51:32Z
closed: 2026-11-14T19:51:32Z
+++

Missing Schema/vectorscript.schema.json for editor completion. A test must check that the example files validate against it.

- `2026-11-14T19:51:32Z`: Schema added. The validation test runs uvx check-jsonschema and is skipped when uvx is not installed.

---

## 21: No golden image tests

+++
status: closed
priority: medium
kind: task
milestone: v1
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:51:32Z
closed: 2026-11-14T19:51:32Z
+++

Rendering has no regression tests. Expected: Tests/Goldens/*.json with committed PNGs in Tests/GoldenImages, one per feature area, compared with schwa/GoldenImage (ignoreEdgeAAHalos, 60 dB).

- `2026-11-14T19:51:32Z`: Implemented in the initial v1 commit.

---

## 22: No format reference or examples

+++
status: closed
priority: medium
kind: documentation
milestone: v1
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:51:32Z
closed: 2026-11-14T19:51:32Z
+++

README.md does not describe the format, and there are no files in Examples/. Every example must parse and render in a test.

- `2026-11-14T19:51:32Z`: Implemented in the initial v1 commit.

---

## 23: No pattern fills

+++
status: open
priority: high
kind: feature
labels: effort:m, area:paint
milestone: later
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:52:23Z
+++

Tiled pattern paints are not supported.

- `2026-11-14T19:52:23Z`: Related: needed for #37 (SVG lowering to VectorScript).

---

## 24: No masks

+++
status: open
priority: medium
kind: feature
labels: effort:m, area:paint
milestone: later
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:52:23Z
+++

Luminance and alpha masks are not supported.

- `2026-11-14T19:52:23Z`: Related: needed for #37 (SVG lowering to VectorScript).

---

## 25: No blend modes

+++
status: open
priority: low
kind: feature
labels: effort:s, area:render
milestone: later
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:52:23Z
+++

Elements and groups cannot set a blend mode.

---

## 26: No filters

+++
status: open
priority: low
kind: feature
labels: effort:l, area:render
milestone: later
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:52:23Z
+++

Filters such as blur and drop shadow are not supported.

- `2026-11-14T19:52:23Z`: Related: needed for #37 (SVG lowering to VectorScript).

---

## 27: No raster image element

+++
status: open
priority: medium
kind: feature
labels: effort:m, area:elements
milestone: later
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:52:23Z
+++

Raster images cannot be embedded or referenced.

- `2026-11-14T19:52:23Z`: Related: needed for #37 (SVG lowering to VectorScript).

---

## 28: No markers

+++
status: open
priority: low
kind: feature
labels: effort:m, area:elements
milestone: later
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:52:23Z
+++

Line markers such as arrowheads are not supported.

- `2026-11-14T19:52:23Z`: Related: needed for #37 (SVG lowering to VectorScript).

---

## 29: No multi-line text

+++
status: open
priority: low
kind: feature
labels: effort:m, area:text
milestone: later
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:52:23Z
+++

Text cannot span lines or wrap.

---

## 30: No font files

+++
status: open
priority: low
kind: feature
labels: effort:s, area:text
milestone: later
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:52:23Z
+++

Text cannot use a font from a file, so output depends on the fonts installed on the machine.

---

## 31: No letter spacing

+++
status: open
priority: low
kind: feature
labels: effort:xs, area:text
milestone: later
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:52:23Z
+++

Text cannot set letter spacing.

---

## 32: No text on a path

+++
status: open
priority: low
kind: feature
labels: effort:l, area:text
milestone: later
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:52:23Z
+++

Text cannot follow a path.

---

## 33: No parameters or expressions

+++
status: open
priority: medium
kind: feature
labels: effort:l, area:format
milestone: later
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:52:23Z
+++

Documents cannot declare parameters or use expressions in place of numbers, as ModelScript does with $NAME and {expression}.

- `2026-11-14T19:52:23Z`: Related: #39. ModelScript already has $NAME parameters and expressions.

---

## 34: No animation

+++
status: open
priority: low
kind: feature
labels: effort:xl, area:format
milestone: later
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:52:23Z
+++

Documents are static; nothing can change over time.

---

## 35: No preserveAspectRatio

+++
status: open
priority: low
kind: feature
labels: effort:s, area:format
milestone: later
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:52:23Z
+++

When viewBox and size have different aspect ratios the content scales non-uniformly, with no way to fit or fill.

---

## 36: No SVG export

+++
status: open
priority: medium
kind: feature
labels: effort:m, area:interop
milestone: later
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:52:23Z
+++

A document cannot be converted to an SVG file.

- `2026-11-14T19:52:23Z`: Related: #37 (the opposite direction).

---

## 37: SVG cannot lower to VectorScript

+++
status: open
priority: medium
kind: feature
labels: effort:xl, area:interop
milestone: later
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:52:23Z
+++

The SVG package (~/Projects/Scratch/SVG) has its own DisplayList. It cannot yet target resolved VectorScript documents. Blocking gaps: masks, patterns, filters, images, markers and instances.

- `2026-11-14T19:52:23Z`: Related: #23, #24, #26, #27, #28 and #38 are the gaps between VectorScript and SVG's DisplayList.
- `2026-11-14T19:52:23Z`: Related: #36 (the opposite direction).

---

## 38: No instances in resolved documents

+++
status: open
priority: medium
kind: feature
labels: effort:m, area:format
milestone: later
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:52:23Z
+++

A resolved document expands every use, so repeated content is duplicated instead of drawn from one shared definition.

- `2026-11-14T19:52:23Z`: Related: needed for #37 (SVG lowering to VectorScript).

---

## 39: ModelScript cannot use VectorScript

+++
status: open
priority: high
kind: feature
labels: effort:l, area:interop
milestone: later
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:52:23Z
+++

ModelScript (~/Projects/Scratch/ModelScript) has no textures or UVs and cannot reference VectorScript graphics.

- `2026-11-14T19:52:23Z`: Related: #33 (parameters), which would let ModelScript pass values into textures.

---

## 40: No SwiftUI renderer

+++
status: open
priority: low
kind: feature
labels: effort:m, area:render
milestone: later
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:52:23Z
+++

Documents can only be drawn through CoreGraphics; there is no SwiftUI view or GraphicsContext renderer.

---

## 41: Viewer source editor has no syntax highlighting

+++
status: open
priority: low
kind: enhancement
labels: effort:m, area:viewer
milestone: viewer
created: 2026-11-14T19:58:49Z
+++

The JSON5 source in the viewer (Examples/VectorScriptViewer) is plain monospaced text. Keys, strings, numbers, comments and punctuation all look the same.

---

## 42: Viewer is not a document-based app

+++
status: closed
priority: medium
kind: enhancement
labels: effort:m, area:viewer
milestone: viewer
created: 2026-11-14T19:58:49Z
updated: 2026-11-14T20:26:17Z
closed: 2026-11-14T20:26:17Z
+++

The viewer (Examples/VectorScriptViewer) is a single WindowGroup with its own open, save and reload handling. There is no File > New, no recent documents, no multiple documents in separate windows, no autosave or versions, and no system handling of unsaved changes when closing a window or quitting.

- `2026-11-14T20:26:17Z`: Viewer now uses DocumentGroup with the Document protocol (OS 27).

---

## Milestone: v1

+++
status: open
created: 2026-11-14T19:15:38Z
+++

First usable release: authored JSON format, resolver, CoreGraphics renderer, CLI.

---

## Milestone: later

+++
status: open
created: 2026-11-14T19:15:38Z
+++

Features beyond v1, including parity with SVG's DisplayList.

---

## Milestone: viewer

+++
status: open
created: 2026-11-14T19:58:44Z
+++

The example viewer and editor app.

---
