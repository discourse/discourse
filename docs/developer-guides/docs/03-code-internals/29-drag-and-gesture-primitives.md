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

| I want to…                                                                              | Use                                                       |
| --------------------------------------------------------------------------------------- | --------------------------------------------------------- |
| Move something onto a target and transfer a payload                                     | `dDragAndDropSource` + `dDragAndDropTarget`               |
| React to a drag without being a drop target                                             | `dDragAndDropMonitor`                                     |
| Scroll a container while a drag is in flight                                            | `dDragAndDropAutoScroll`                                  |
| Receive files/HTML/text dragged in from outside the browser, and handle them myself     | `dDragAndDropExternalTarget`                              |
| Receive a link or image the browser dragged from **this page**, that nothing registered | `dDragAndDropTarget` with `adopts`                        |
| Receive dropped files **for upload**                                                    | the Uppy `DropTarget` path, **not** the modifier above    |
| Read whether, and what, is currently being dragged — reactively                         | `@service dragAndDrop`                                    |
| Press, drag, and change a value continuously                                            | `dPointerDrag`                                            |
| Put a resize handle between two regions                                                 | `DResizeSeparator`                                        |
| Resize along one axis, supplying my own element and semantics                           | `dResizeEdge`                                             |
| Resize a box in two dimensions from its edges and corners                               | `DResizeHandles`                                          |
| Detect a directional touch swipe                                                        | `dSwipe` — a discrete gesture, not a continuous transform |
| Anything, using `dDraggable`                                                            | Don't — deprecated; its notice names the replacement      |

That last row is enforced rather than advisory. `dDraggable` raises the
`discourse.ui-kit.d-draggable` deprecation the moment it is instantiated, and
nothing silences it, so a usage in core or a preinstalled plugin fails the test
suite. A theme or plugin gets a console warning attributed to it instead. The
migration notes — including the three behaviour differences that matter — live in
its own JSDoc.

# The three boundaries

Each of these is a live trap: both options appear to work, and only one is correct.

## `dOnResize` observes; `dResizeEdge` and `DResizeHandles` perform

Three similarly named files sit in `ui-kit/modifiers/`, and only two of them are
gestures.

- **`dOnResize`** wraps a `ResizeObserver`. It tells you an element's size
  _changed_ — by layout, by a font load, by a sibling growing. Nobody dragged
  anything.
- **`dResizeEdge`** and **`DResizeHandles`** are how a user _performs_ a resize.

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

Where the two targets do agree is on _position_. Give the external target an
`axis` and it resolves `before` / `after` from the cursor midpoint and draws the
same `--drag-above` / `--drag-below` indicators the element target does, which is
what a row an incoming link should land beside needs. Without an `axis` it stays
a single destination: callbacks get `position: null` and the indicator is one
`--drag-over-external` class. Most external targets want that; a drop zone is a
destination, not a slot.

Auto-scroll splits the same way. `dDragAndDropAutoScroll` registers for element
drags by default and scrolls nothing for a payload dragged in from outside;
`accepts` adds the external registration beside it. So a scroll container that a
drop can land in wants both, and a container attached without `accepts` will
look wired up while leaving an incoming drag stuck at the fold.

## An ancestor that must stay lit reads the service

Only the deepest accepted target receives the lifecycle callbacks. That is
usually what you want, and it is why nested targets do not double-handle a
drop — but it also means an ancestor target goes dark the moment a descendant
claims the drag.

So a container that should stay highlighted for the whole drag while its rows
each light up in turn cannot get that from a target of its own. Read
`@service dragAndDrop` there instead — `isDragging`, `acceptsExternal(kind)`,
`accepts(type)` — and leave the targets to the rows. This is the same
read-versus-respond split as the boundary below, arriving from a different
direction.

## The monitor reacts; the service holds state

- **`dDragAndDropMonitor`** takes `types` plus `onDragStart` / `onDrag` /
  `onDrop`, for imperative reaction to a drag happening elsewhere.
- **`@service dragAndDrop`** exposes `currentDrag` and `isDragging` as tracked
  state, for rendering.

Use the service to **read**, the monitor to **respond**. Rendering from the
monitor's callbacks means hand-maintaining state the service already keeps.

## What the cursor says

Two separate things decide it, and reaching for the wrong one is why the badge
under the pointer is hard to shift.

**What the drag permits** is `effectAllowed`, written once at `dragstart` and not
touched again. Left unwritten it means "anything", which the browser renders as
its standing offer to copy, so `dDragAndDropSource` declares `"move"` — what a
drag between two places in the same page almost always is.

That default is a real constraint, not just a cursor: `getDropEffect` may only
return an effect the source permits, so a target asking for `"copy"` under it
shows the pointer as **refused**. A source whose drop genuinely duplicates rather
than relocates passes `effectAllowed="copyMove"`, which permits both.

**Whether anything wants the drop** is `dropEffect`, and a sourced drag answers
for itself everywhere no target accepts it. That is about the ending rather than
the pointer: releasing over dead space finishes the drag where it is, instead of
playing the browser's snap-back animation.

A drag this suite **adopted** is excluded from both. The browser started it and
it carries a real payload, so dropping it on a text field or any other surface on
the page is something that surface should still be able to handle. Adopted drags
keep whatever the browser decided, its copy cursor included.

# Resize: which of the three

`DResizeSeparator` and `dResizeEdge` are the same gesture at two levels, and
`DResizeHandles` is a different shape entirely.

- **`DResizeSeparator`** is the one to reach for by default. It wraps
  `dResizeEdge` and supplies everything a consumer would otherwise hand-write
  beside it: the `role="separator"` contract, one tab stop, the `aria-orientation`
  that is the _opposite_ of the axis, and a tracked mirror of the size for
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
  file-drop path — drag implementations this consolidation does not touch. Note
  that `adopts` deliberately steps around all three: it refuses an element that
  is already draggable, one inside a registered source, and any drag that began
  as a text selection.
- **`dOnResize`**, **`dObserveIntersection`**, **`dScrollIntoView`** — observers,
  not gestures. See the first boundary above.

`dSwipe` is the one boundary case that stays _in_ this guide while sitting outside
the drag suite, because it is still an input-driven gesture. It reports a
directional flick with a velocity — a discrete outcome. If you want a value that
tracks the pointer continuously, you want `dPointerDrag`.

# Accessibility

A drag is not reachable by keyboard, so any surface whose only path to an outcome
is a drag has no keyboard path at all. A new consumer must pair its drag with
something else — arrow buttons at a reorder surface, the keyboard path built into
`dResizeEdge` at a resize.

Every reorder surface in core does: the dashboard configure menu, the
manage-reports modal, and the sidebar section-link form all render
`DReorderButtons` beside the handle. Both paths render on every viewport, and
neither substitutes for the other: the arrows are the only route without a
pointer, and the drag is the only route without a keyboard.

A grip is what makes that safe on a touch screen. All three surfaces pass
`dragHandle`, so a drag begins on the grip rather than anywhere on the row, and
a press that was meant to scroll still scrolls. A surface that leaves its whole
row draggable should not then offer that row on touch.

The grip is also what keeps the rest of the row usable. `draggable="true"` is
what makes a browser read a press-drag as a drag instead of a selection, so
whichever element carries it has no selectable text — which is why `dragHandle`
moves the registration onto the handle rather than merely narrowing where a drag
may begin. The row stays the body throughout: it is what the state modifiers land
on, what a target receives as `source.element`, and what the drag preview
photographs. Style and assert on `data-drag-source`, never on `draggable`, since
only the former is always on the row.

Arrows and a drag do not have to reach the same destinations. The sidebar's
arrows move a link within its own list, while its drag also moves links between
the primary and "More menu" lists: the two lists render under separate headings,
so arrowing across that boundary would take the link out of the list being
arrowed through. Match the arrows to the list the user is stepping through, and
leave the wider rearrangement to the pointer.

No gesture moves focus. A handle usually sits against the thing it acts on, and
taking focus on press would pull the caret out of whatever the user was working
in. So a handle that is operable needs its own tab stop to be reachable; it will
never be handed focus by being dragged.

`aria-dropeffect` and `aria-grabbed` are **deliberately not used** anywhere in this
suite. Both were deprecated in ARIA 1.1 and have no assistive-technology support;
adding them signals support that does not exist.

Announce the _outcome_, not the gesture. A drop that reorders something should
report where the item landed, once, through `a11y.announce()`. Do not announce the
drop indicator moving: the gesture is unreachable by assistive technology, so
narrating hover position is noise for the only people who would hear it.
