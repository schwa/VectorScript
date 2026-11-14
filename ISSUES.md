# ISSUES.md

File format: <https://github.com/schwa/issues-format>

---

## 1: No document model

+++
status: new
priority: medium
kind: feature
milestone: v1
created: 2026-11-14T19:15:38Z
+++

There are no public Swift types for a VectorScript document: canvas (size, optional viewBox, background), version, defs and elements. Types must be public, Sendable, Equatable, have memberwise initialisers, and must not import CoreGraphics.

---

## 2: No strict JSON5 decoding

+++
status: new
priority: medium
kind: feature
milestone: v1
created: 2026-11-14T19:15:38Z
+++

Documents cannot be read from JSON5. Decoding must be strict: unknown keys, more than one type key on an element, and unknown versions are errors. Error messages must name the coding path, for example elements[3].fill.

---

## 3: No JSON encoding of documents

+++
status: new
priority: medium
kind: feature
milestone: v1
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:15:39Z
+++

Documents cannot be written back to JSON. Decode then encode then decode must give an equal document.

---

## 4: No basic shapes

+++
status: new
priority: medium
kind: feature
milestone: v1
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:15:39Z
+++

Missing elements: rect (with corner radius), circle, ellipse, line, polyline, polygon. Elements are keyed by type with compact array arguments, for example { circle: [cx, cy, r] }.

---

## 5: No path element

+++
status: new
priority: medium
kind: feature
milestone: v1
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:15:39Z
+++

Missing the path element, which takes SVG path data: M L H V C S Q T A Z in absolute and relative forms, implicit repeats, SVG number syntax (1-2, .5.5) and arc flags.

---

## 6: No groups

+++
status: new
priority: medium
kind: feature
milestone: v1
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:15:39Z
+++

Missing the group element: { group: [elements], ... } with its own style, opacity, transform and clip.

---

## 7: No transforms

+++
status: new
priority: medium
kind: feature
milestone: v1
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:15:39Z
+++

Missing transform on elements. Forms: an SVG transform string, an ordered array of single-operation objects, or one operation object. Operations: translate, rotate (optional centre), scale, skewX, skewY, matrix. Order follows SVG.

---

## 8: No colour parsing

+++
status: new
priority: medium
kind: feature
milestone: v1
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:15:39Z
+++

Missing colour values: #rgb, #rgba, #rrggbb, #rrggbbaa, CSS named colours and none. Unknown colours are errors.

---

## 9: No gradients

+++
status: new
priority: medium
kind: feature
milestone: v1
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:15:39Z
+++

Missing linearGradient and radialGradient paints, written inline or in defs. Stops are [offset, colour] pairs. Coordinates are relative to the shape bounding box by default; units: user makes them absolute.

---

## 10: No defs, use or $name references

+++
status: new
priority: medium
kind: feature
milestone: v1
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:15:39Z
+++

Missing defs (one flat namespace of paints and elements), use (name, optional at, transform, style overrides) and $name paint references. Unresolved references and use cycles are errors.

---

## 11: No style inheritance

+++
status: new
priority: medium
kind: feature
milestone: v1
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:15:39Z
+++

fill, stroke, stroke properties, fillRule and font properties do not inherit from groups. opacity, transform and clip must not inherit. Defaults: fill black, stroke none.

---

## 12: No stroke properties

+++
status: new
priority: medium
kind: feature
milestone: v1
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:15:39Z
+++

Missing strokeWidth, strokeCap, strokeJoin, strokeMiterLimit, strokeDash and strokeDashOffset.

---

## 13: No fill rule

+++
status: new
priority: medium
kind: feature
milestone: v1
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:15:39Z
+++

Missing fillRule: nonzero or evenodd.

---

## 14: No opacity

+++
status: new
priority: medium
kind: feature
milestone: v1
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:15:39Z
+++

Missing opacity on elements and groups. Group opacity applies to the group as a whole.

---

## 15: No clipping

+++
status: new
priority: medium
kind: feature
milestone: v1
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:15:39Z
+++

Missing clip on elements and groups, taking a shape or path.

---

## 16: No text element

+++
status: new
priority: medium
kind: feature
milestone: v1
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:15:39Z
+++

Missing single-line text: { text, at, font, fontSize, anchor }. at is the baseline origin. anchor is start, middle or end. Fonts come from the system; an unknown font is an error. Text fills, strokes and clips like a path.

---

## 17: No resolve pass

+++
status: new
priority: medium
kind: feature
milestone: v1
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:15:39Z
+++

There is no way to turn an authored document into a resolved one. A resolved document is valid VectorScript with explicit styles, no references, use expanded and transforms as matrices. resolve() must be pure and live in the portable target.

---

## 18: No CoreGraphics renderer

+++
status: new
priority: medium
kind: feature
milestone: v1
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:15:39Z
+++

Resolved documents cannot be drawn. Missing a VectorScriptRender target that draws into a CGContext and produces CGImage, PNG, JPEG and PDF, with a scale factor and size override.

---

## 19: No command line tool

+++
status: new
priority: medium
kind: feature
milestone: v1
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:15:39Z
+++

Missing the vectorscript executable: render input [-o output] [--scale] [--size WxH] [--format png|pdf|jpeg], and validate input. Format is inferred from the output extension. Errors name the coding path and exit non-zero.

---

## 20: No JSON Schema

+++
status: new
priority: medium
kind: feature
milestone: v1
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:15:39Z
+++

Missing Schema/vectorscript.schema.json for editor completion. A test must check that the example files validate against it.

---

## 21: No golden image tests

+++
status: new
priority: medium
kind: task
milestone: v1
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:15:39Z
+++

Rendering has no regression tests. Expected: Tests/Goldens/*.json with committed PNGs in Tests/GoldenImages, one per feature area, compared with schwa/GoldenImage (ignoreEdgeAAHalos, 60 dB).

---

## 22: No format reference or examples

+++
status: new
priority: medium
kind: documentation
milestone: v1
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:15:39Z
+++

README.md does not describe the format, and there are no files in Examples/. Every example must parse and render in a test.

---

## 23: No pattern fills

+++
status: new
priority: medium
kind: feature
milestone: later
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:15:39Z
+++

Tiled pattern paints are not supported.

---

## 24: No masks

+++
status: new
priority: medium
kind: feature
milestone: later
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:15:39Z
+++

Luminance and alpha masks are not supported.

---

## 25: No blend modes

+++
status: new
priority: medium
kind: feature
milestone: later
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:15:39Z
+++

Elements and groups cannot set a blend mode.

---

## 26: No filters

+++
status: new
priority: medium
kind: feature
milestone: later
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:15:39Z
+++

Filters such as blur and drop shadow are not supported.

---

## 27: No raster image element

+++
status: new
priority: medium
kind: feature
milestone: later
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:15:39Z
+++

Raster images cannot be embedded or referenced.

---

## 28: No markers

+++
status: new
priority: medium
kind: feature
milestone: later
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:15:39Z
+++

Line markers such as arrowheads are not supported.

---

## 29: No multi-line text

+++
status: new
priority: medium
kind: feature
milestone: later
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:15:39Z
+++

Text cannot span lines or wrap.

---

## 30: No font files

+++
status: new
priority: medium
kind: feature
milestone: later
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:15:39Z
+++

Text cannot use a font from a file, so output depends on the fonts installed on the machine.

---

## 31: No letter spacing

+++
status: new
priority: medium
kind: feature
milestone: later
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:15:39Z
+++

Text cannot set letter spacing.

---

## 32: No text on a path

+++
status: new
priority: medium
kind: feature
milestone: later
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:15:39Z
+++

Text cannot follow a path.

---

## 33: No parameters or expressions

+++
status: new
priority: medium
kind: feature
milestone: later
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:15:39Z
+++

Documents cannot declare parameters or use expressions in place of numbers, as ModelScript does with $NAME and {expression}.

---

## 34: No animation

+++
status: new
priority: medium
kind: feature
milestone: later
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:15:39Z
+++

Documents are static; nothing can change over time.

---

## 35: No preserveAspectRatio

+++
status: new
priority: medium
kind: feature
milestone: later
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:15:39Z
+++

When viewBox and size have different aspect ratios the content scales non-uniformly, with no way to fit or fill.

---

## 36: No SVG export

+++
status: new
priority: medium
kind: feature
milestone: later
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:15:39Z
+++

A document cannot be converted to an SVG file.

---

## 37: SVG cannot lower to VectorScript

+++
status: new
priority: medium
kind: feature
milestone: later
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:15:39Z
+++

The SVG package (~/Projects/Scratch/SVG) has its own DisplayList. It cannot yet target resolved VectorScript documents. Blocking gaps: masks, patterns, filters, images, markers and instances.

---

## 38: No instances in resolved documents

+++
status: new
priority: medium
kind: feature
milestone: later
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:15:39Z
+++

A resolved document expands every use, so repeated content is duplicated instead of drawn from one shared definition.

---

## 39: ModelScript cannot use VectorScript

+++
status: new
priority: medium
kind: feature
milestone: later
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:15:39Z
+++

ModelScript (~/Projects/Scratch/ModelScript) has no textures or UVs and cannot reference VectorScript graphics.

---

## 40: No SwiftUI renderer

+++
status: new
priority: medium
kind: feature
milestone: later
created: 2026-11-14T19:15:38Z
updated: 2026-11-14T19:15:39Z
+++

Documents can only be drawn through CoreGraphics; there is no SwiftUI view or GraphicsContext renderer.

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
