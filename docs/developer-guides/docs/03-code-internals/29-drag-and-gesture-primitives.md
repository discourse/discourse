---
title: Choosing between Discourse's drag and gesture primitives.
short_title: Drag and gesture primitives
id: drag-and-gesture-primitives
---

<div data-theme-toc="true"> </div>

# What this covers

`ui-kit` ships a dozen input-driven gesture primitives, and several of them read as
interchangeable from their filenames alone. This guide says which one to reach for,
and — more importantly — draws the three boundaries that are easy to cross by
accident.

The membership rule is **input-driven gestures only**: something the user performs
with a pointer, a touch, or a key. That keeps `dSwipe` in, and keeps `dOnResize`
out, because a `ResizeObserver` wrapper is triggered by DOM state rather than by
input. `dOnResize` appears below only as a disambiguation note.

# Pick by intent

| I want to… | Use |
| --- | --- |
| Move something onto a target and transfer a payload | `dDragAndDropSource` + `dDragAndDropTarget` |
| React to a drag without being a drop target | `dDragAndDropMonitor` |
| Scroll a container while a drag is in flight | `dDragAndDropAutoScroll` |
| Receive files/HTML/text dragged in from outside the browser, and handle them myself | `dDragAndDropExternalTarget` |
| Receive dropped files **for upload** | the Uppy `DropTarget` path, **not** the modifier above |
| Read whether, and what, is currently being dragged — reactively | `@service dragAndDrop` |
| Press, drag, and change a value continuously | `dPointerDrag` |
| Put a resize handle between two regions | `DResizeSeparator` |
| Resize along one axis, supplying my own element and semantics | `dResizeEdge` |
| Resize a box in two dimensions from its edges and corners | `DResizeHandles` |
| Detect a directional touch swipe | `dSwipe` — a discrete gesture, not a continuous transform |
| Anything, using `dDraggable` | Don't — deprecated; its notice names the replacement |

# The three boundaries

Each of these is a live trap: both options appear to work, and only one is correct.

## `dOnResize` observes; `dResizeEdge` and `DResizeHandles` perform

Three similarly named files sit in `ui-kit/modifiers/`, and only two of them are
gestures.

- **`dOnResize`** wraps a `ResizeObserver`. It tells you an element's size
  *changed* — by layout, by a font load, by a sibling growing. Nobody dragged
  anything.
- **`dResizeEdge`** and **`DResizeHandles`** are how a user *performs* a resize.

If you want to know a size, observe. If you want to let someone change one, perform.

## `dDragAndDropExternalTarget` is not the upload path

This is the most consequential overlap in the set, because both appear to work and
only one uploads.

- **`dDragAndDropExternalTarget`** handles arbitrary payloads dragged in from
  outside the browser — text, HTML, URLs, and files you intend to process
  yourself. It hands you the payload and stops there.
- **Uppy's `DropTarget` plugin** — registered in `lib/uppy/uppy-upload.js` — is
  what wires a file drop into the upload pipeline: progress, validation, retries,
  the upload record.

A file dropped on the modifier will not upload. Reach for the modifier only when
you genuinely want the raw payload.

## The monitor reacts; the service holds state

- **`dDragAndDropMonitor`** takes `types` plus `onDragStart` / `onDrag` /
  `onDrop`, for imperative reaction to a drag happening elsewhere.
- **`@service dragAndDrop`** exposes `currentDrag` and `isDragging` as tracked
  state, for rendering.

Use the service to **read**, the monitor to **respond**. Rendering from the
monitor's callbacks means hand-maintaining state the service already keeps.

# Resize: which of the three

`DResizeSeparator` and `dResizeEdge` are the same gesture at two levels, and
`DResizeHandles` is a different shape entirely.

- **`DResizeSeparator`** is the one to reach for by default. It wraps
  `dResizeEdge` and supplies everything a consumer would otherwise hand-write
  beside it: the `role="separator"` contract, one tab stop, the `aria-orientation`
  that is the *opposite* of the axis, and a tracked mirror of the size for
  `aria-valuenow` / `min` / `max` that keeps up with size changes no gesture
  caused.
- **`dResizeEdge`** is the modifier underneath. Use it directly only when the
  element and its semantics are already yours to own — and then you are
  responsible for the separator contract above.
- **`DResizeHandles`** is two-dimensional: eight compass handles around a box. The
  separator role does **not** apply to it, and must not be used — a 2D resize has
  no single `aria-valuenow` to report.

That last distinction is not cosmetic. Only a 1D resize between two regions is a
separator; giving a 2D box-resize the same role tells assistive technology
something untrue about it.

# Deliberately out of the suite

So nobody tries to force them in:

- **`chat/resizable-node`** — 2D with repositioning, plugin-local, staying where
  it is.
- **ProseMirror image drag**, **workflow expression dragging**, and every Uppy
  file-drop path — drag implementations this consolidation does not touch.
- **`dOnResize`**, **`dObserveIntersection`**, **`dScrollIntoView`** — observers,
  not gestures. See the first boundary above.

`dSwipe` is the one boundary case that stays *in* this guide while sitting outside
the drag suite, because it is still an input-driven gesture. It reports a
directional flick with a velocity — a discrete outcome. If you want a value that
tracks the pointer continuously, you want `dPointerDrag`.

# Accessibility

A drag is not reachable by keyboard, so any surface whose only path to an outcome
is a drag has no keyboard path at all. Every consumer in core pairs its drag with
something else — arrow buttons at the reorder surfaces, the keyboard path built
into `dResizeEdge` — and a new one should too.

`aria-dropeffect` and `aria-grabbed` are **deliberately not used** anywhere in this
suite. Both were deprecated in ARIA 1.1 and have no assistive-technology support;
adding them signals support that does not exist.

Announce the *outcome*, not the gesture. A drop that reorders something should
report where the item landed, once, through `a11y.announce()`. Do not announce the
drop indicator moving: the gesture is unreachable by assistive technology, so
narrating hover position is noise for the only people who would hear it.
