---
title: Choosing between Discourse's drag and gesture primitives
short_title: Drag and gesture primitives
id: drag-and-gesture-primitives
---

<div data-theme-toc="true"> </div>

# What this covers

`ui-kit` ships several input-driven gesture primitives, and their filenames can
make them appear interchangeable. This guide identifies which primitive to use
and draws the boundaries that are easy to cross accidentally.

The membership rule is **input-driven gestures**: something a user performs with
a pointer, touch, or key. That includes `dSwipe` but excludes `dOnResize`, because
the latter responds to DOM state through `ResizeObserver`. `dOnResize` appears
below only to disambiguate it from the resize gestures.

# Pick by intent

| I want to…                                                                           | Use                                                      |
| ------------------------------------------------------------------------------------ | -------------------------------------------------------- |
| Move something onto a target and transfer a payload                                  | `dDragAndDropSource` + `dDragAndDropTarget`              |
| React to a drag without becoming a drop target                                       | `dDragAndDropMonitor`                                    |
| Scroll a container while a drag is in flight                                         | `dDragAndDropAutoScroll`                                 |
| Receive files, HTML, or text dragged in from outside the window and handle it myself | `dDragAndDropExternalTarget`                             |
| Receive page content from a browser-started drag that no source registered           | `dDragAndDropTarget` with `adopts`                       |
| Receive dropped files for upload                                                     | the existing upload pipeline, not the modifier above     |
| Read the current drag reactively                                                     | `@service dragAndDrop`                                   |
| Press, drag, and change a value continuously                                         | `dPointerDrag`                                           |
| Put an accessible resize handle between two regions                                  | `DResizeSeparator`                                       |
| Resize along one axis while supplying my own element and semantics                   | `dResizeEdge`                                            |
| Resize a box in two dimensions from its edges and corners                            | `DResizeHandles`                                         |
| Detect a directional touch swipe                                                     | `dSwipe`, for a discrete gesture rather than a transform |
| Implement anything with `dDraggable`                                                 | Don't: it is deprecated and names its replacement        |

That last row is enforced rather than advisory. Instantiating `dDraggable`
raises the `discourse.ui-kit.d-draggable` deprecation. Its own API documentation
describes the replacement and the behavior differences that matter during a
migration.

# Important boundaries

## `dOnResize` observes; the resize primitives perform

Three similarly named APIs do different jobs:

- **`dOnResize`** wraps `ResizeObserver`. It reports that layout changed, whether
  because of a font load, a growing sibling, or a gesture elsewhere.
- **`dResizeEdge`** and **`DResizeHandles`** let a user perform a resize.

If you need to know an element's size, observe it. If you need to let someone
change that size, use a gesture primitive.

## An external target is not the upload path

This is a consequential overlap because both options can receive a file, but
only one uploads it.

- **`dDragAndDropExternalTarget`** hands the consumer an incoming native payload:
  text, HTML, URLs, or files it intends to process itself.
- **The upload pipeline's drop target** owns upload validation, progress,
  retries, and the upload record.

A file dropped on the modifier does not enter the upload pipeline. Use the
modifier only when the consumer genuinely wants the raw payload.

The element and external targets do share position behavior. Give the external
target an `axis` and it resolves `before` or `after` from the pointer midpoint,
using the same `--drag-above` and `--drag-below` indicators as an element target.
Without an `axis`, it remains a single destination: callbacks receive
`position: null`, and the target receives `--drag-over-external`.

Auto-scroll splits the same way. `dDragAndDropAutoScroll` watches element drags
by default; its `accepts` argument adds a separate registration for incoming
external payloads. A scrolling external drop surface normally needs both the
target and the matching auto-scroll registration.

## Page-content adoption is opt-in

A browser can start a drag from page content that no `dDragAndDropSource`
registered, such as a link or image. An element target receives such content
only when its `adopts` predicate claims it.

The adoption snapshots the readable native payload during `dragstart`, then
routes the drag through the ordinary element target, monitor, service, and
auto-scroll lifecycle. Consumers filter on the type they declared and find the
native reader API on `source.native`.

Adoption deliberately leaves several drags alone:

- a registered source keeps its own type and lifecycle;
- an explicitly draggable element stays owned by its existing implementation;
- selected or editable text remains a browser text drag; and
- files remain available to the upload path.

It also preserves browser behavior over dead space and does not narrow the
browser's allowed effects.

## An ancestor that must stay active reads the service

Only the deepest accepted target receives lifecycle callbacks. That prevents
nested targets from handling one drop twice, but it also means an ancestor
target stops indicating as soon as a descendant claims the drag.

If a container must stay highlighted while its descendant targets activate in
turn, read `@service dragAndDrop` instead. Its tracked `currentDrag`,
`currentExternalDrag`, and `isDragging` state describe the in-flight operation;
`accepts(type)` and `acceptsExternal(kind)` provide the matching vocabulary.
Leave drop handling to the descendant targets.

## The monitor reacts; the service holds state

- **`dDragAndDropMonitor`** invokes `onDragStart`, `onDrag`, and `onDrop` for
  imperative reactions to an element drag happening elsewhere.
- **`@service dragAndDrop`** exposes tracked state for rendering.

Use the service to read and the monitor to respond. Rendering from monitor
callbacks means maintaining state that the service already owns.

## The source and target jointly determine cursor feedback

`effectAllowed` says what a registered source permits. It is written once at
`dragstart`; `dDragAndDropSource` defaults it to `"move"`, which suits moving an
item between positions on the same page. A source that truly supports both
copying and moving can pass `effectAllowed="copyMove"`.

`getDropEffect` says which permitted operation a target would perform. A target
requesting `"copy"` from a move-only source is refused by the browser because a
target cannot broaden the source's permission.

A registered source also claims otherwise-unhandled space for the duration of
its drag, so releasing over dead space finishes without the browser's snap-back
animation. An adopted drag is excluded from both behaviors: the browser started
it with a real native payload, so other page surfaces must remain able to handle
it according to the browser's original rules.

# Choosing a resize primitive

`DResizeSeparator` and `dResizeEdge` expose the same one-dimensional gesture at
different levels, while `DResizeHandles` serves a different shape.

- **`DResizeSeparator`** is the default for resizing between two regions. It
  wraps `dResizeEdge` and provides `role="separator"`, one tab stop, keyboard
  operation, the correct orientation, bounds, and live ARIA value updates.
- **`dResizeEdge`** is the modifier underneath. Use it directly only when the
  element and separator semantics are already yours to provide.
- **`DResizeHandles`** renders the edges and corners of a two-dimensional box
  resize and reports pointer geometry for the consumer to interpret.

Do not give a two-dimensional box resize `role="separator"`. It has no single
`aria-valuenow` to report, so that role would describe a control that does not
exist.

# Deliberately separate implementations

Not every drag belongs in this shared suite. Specialized content manipulation,
spatial gestures, and upload drop paths can have domain-specific lifecycles that
do not map to these primitives. Adoption steps around existing draggable
elements, registered sources, text selections, and files so those owners retain
control.

Observer modifiers such as `dOnResize`, `dObserveIntersection`, and
`dScrollIntoView` are also outside the gesture suite because they react to DOM
state rather than input.

`dSwipe` remains in this guide because it is input-driven. It reports a discrete
directional flick with velocity. Use `dPointerDrag` when a value must track the
pointer continuously.

# Accessibility

A drag is not a keyboard interaction. Any reorder surface must pair it with a
keyboard path, such as `DReorderButtons`; a resize between regions should use
the keyboard support in `DResizeSeparator` or `dResizeEdge`.

Use `DDragHandle` with `dragHandle` for reorder rows. The grip confines the drag
start so a touch press intended to scroll still scrolls, and it moves
`draggable="true"` off the row so the row's text and controls remain usable. The
row remains the drag body: it receives state classes, appears as
`source.element`, and supplies the drag preview. Style and assert against
`data-drag-source`, which is always on that body, rather than `draggable`.

`DDragHandle` is decorative and outside the tab order because a keyboard cannot
operate it. `DReorderButtons` provides the operable controls and keeps focus on
the pressed direction after the row moves. Both belong on every viewport.

Drag and arrow paths can have different scopes when the visible structure calls
for it. For example, arrows may move within one labeled list while a drag can
cross between lists. The keyboard path should follow the list the user is
stepping through rather than silently crossing a semantic boundary.

Do not add `aria-dropeffect` or `aria-grabbed`; both are deprecated and do not
provide an operable drag experience.

Announce the outcome, not pointer movement. A successful reorder should report
the item's new visible position once through `a11y.announce()`. A no-op should
announce nothing, and moving the pointer across drop indicators should not
produce announcements.
