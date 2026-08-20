---
title: Drag, resize, and gesture primitives
short_title: Gesture primitives
id: drag-and-gesture-primitives
---

<div data-theme-toc="true"> </div>

`ui-kit` ships the input-driven gesture primitives: dragging a payload onto a
target, resizing a region, and reading a swipe or a pointer drag. This page is
the usage reference. Each primitive's own TSDoc carries the fine print for every
argument; what follows is how to put them together.

# Basic usage

A drag needs a source that carries a payload and a target that accepts its type.

```gjs
import { hash } from "@ember/helper";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";

<template>
  <div {{dDragAndDropSource type="card" data=(hash id=@card.id)}}>
    {{@card.title}}
  </div>

  <div {{dDragAndDropTarget accepts="card" onDrop=@onDrop}}>
    Drop a card here
  </div>
</template>
```

```js
@action
onDrop({ source, position }) {
  // source.data is what the source attached; position is "before" or "after"
  this.file(source.data.id, position);
}
```

The `type` string is the whole matching vocabulary. A target engages only for
sources whose `type` is in its `accepts`, and everything else drags straight
over it.

# Picking a primitive

| I want to…                                                     | Use                                         |
| -------------------------------------------------------------- | ------------------------------------------- |
| Move something onto a target and transfer a payload            | `dDragAndDropSource` + `dDragAndDropTarget` |
| Take page content the browser started dragging, with no source | `dDragAndDropTarget` with `adopts`          |
| Take files, HTML, URLs, or text from outside the window        | `dDragAndDropExternalTarget`                |
| Upload the files somebody dropped                              | the upload pipeline, not the modifier above |
| React to a drag without becoming a drop target                 | `dDragAndDropMonitor`                       |
| Scroll a container while a drag hovers near its edge           | `dDragAndDropAutoScroll`                    |
| Render from the in-flight drag                                 | the `dragAndDrop` service                   |
| Press, move, and track a value continuously                    | `dPointerDrag`                              |
| Put an accessible handle between two regions                   | `DResizeSeparator`                          |
| Resize on one axis with your own element and semantics         | `dResizeEdge`                               |
| Resize a box from its edges and corners                        | `DResizeHandles`                            |
| Detect a directional flick                                     | `dSwipe`                                    |
| Know that an element changed size                              | `dOnResize`, which is not a gesture         |

# dDragAndDropSource

Marks an element draggable and attaches the payload.

## Arguments

| Argument            | Type                            | Purpose                                                                    |
| ------------------- | ------------------------------- | -------------------------------------------------------------------------- |
| `type`              | `string`, required              | The discriminator targets filter on. Overwrites any `type` in the payload. |
| `data`              | `object`                        | Static payload, read back as `source.data`.                                |
| `getInitialData`    | `() => object`                  | Dynamic payload, called once just before `dragstart`.                      |
| `dragPreview`       | `Element` or render function    | What the drag image shows. Defaults to the source element.                 |
| `dragPreviewOffset` | `{x: string, y: string}`        | CSS lengths pushing a rendered preview clear of the pointer.               |
| `effectAllowed`     | `DataTransfer["effectAllowed"]` | What the drag permits. Defaults to `"move"`.                               |
| `dragHandle`        | `Element`                       | An element inside this one that a drag must start from.                    |
| `disabled`          | `boolean`                       | Detaches the registration. A drag in flight still finishes.                |
| `canDrag`           | `(feedback) => boolean`         | Returning `false` blocks the drag from starting.                           |
| `onDragStart`       | `(event) => void`               | Fires once the drag is confirmed.                                          |
| `onDragEnd`         | `(event) => void`               | Fires at the end of every drag, landed or abandoned.                       |
| `onDrop`            | `(event) => void`               | Fires only for a drag that ended on a target.                              |

The element carries `data-drag-source` while registered and `--dragging` for the
duration of the drag. Style and assert against those, never against
`draggable`: that attribute sits on whichever element was registered, which is
the handle when there is one.

## Dragging by a handle

Without a handle the whole element starts a drag, so text inside it cannot be
selected and a touch press meant to scroll starts a drag instead. Pass the
handle element itself, captured with a modifier, not a selector.

```gjs
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { modifier } from "ember-modifier";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";

export default class Row extends Component {
  @tracked gripElement;

  captureGrip = modifier((element) => {
    this.gripElement = element;
    return () => (this.gripElement = undefined);
  });

  <template>
    <li {{dDragAndDropSource type="row" dragHandle=this.gripElement}}>
      <span {{this.captureGrip}} aria-hidden="true"></span>
      {{@item.label}}
    </li>
  </template>
}
```

The row stays the drag body: it keeps `data-drag-source`, it is what a target
reports as `source.element`, and it is what the default preview photographs.

## Custom previews

An `Element` preview is photographed in place. A render function mounts a fresh
preview into an isolated offscreen container, so nothing around the source
bleeds into the drag image, and may return a cleanup function.

```js
dragPreview = ({ container, element }) => {
  const node = element.cloneNode(true);
  container.append(node);
  return () => node.remove();
};
```

# dDragAndDropTarget

Accepts element drags and reports where the drop would land.

## Arguments

| Argument        | Type                                         | Purpose                                                       |
| --------------- | -------------------------------------------- | ------------------------------------------------------------- |
| `accepts`       | `string \| string[]`                         | Which source types engage the target. Omit to accept any.     |
| `adopts`        | `NativeDragAdoption \| NativeDragAdoption[]` | Also take browser-started page content. See below.            |
| `acceptsSelf`   | `boolean`                                    | `false` refuses a drop whose dragged element is this element. |
| `position`      | `"before" \| "after" \| "inside"`            | A fixed position, which wins over midpoint math.              |
| `axis`          | `"vertical" \| "horizontal"`                 | Which midpoint is measured. Defaults to `"vertical"`.         |
| `indicator`     | `boolean`                                    | `false` suppresses the indicator class.                       |
| `canDrop`       | `(feedback) => boolean`                      | Gate asked while hovering. `false` defers to an ancestor.     |
| `getDropEffect` | `(feedback) => DropEffect`                   | The cursor feedback the browser shows.                        |
| `getData`       | `() => object`                               | Metadata attached to the drag's record of this target.        |
| `getIsSticky`   | `() => boolean`                              | Whether the target stays current after the pointer leaves.    |
| `onDragEnter`   | `(event) => void`                            | This target became the deepest accepted target.               |
| `onDrag`        | `(event) => void`                            | Throttled, while it stays the deepest accepted target.        |
| `onDragLeave`   | `(event) => void`                            | It stopped being the deepest accepted target.                 |
| `onDrop`        | `(event) => void`                            | The drag was released here.                                   |

A registered target carries `data-drop-target`.

## Positions and indicator classes

A target resolves `before`, `after` or `inside` and paints one class while a
compatible drag is over it:

| Position | Vertical axis   | Horizontal axis |
| -------- | --------------- | --------------- |
| `before` | `--drag-above`  | `--drag-left`   |
| `after`  | `--drag-below`  | `--drag-right`  |
| `inside` | `--drag-inside` | `--drag-inside` |

Positions are logical, not physical. In a right-to-left row, `before` still
means the reading-order start, and the class flips to `--drag-right` so the
indicator stays under the pointer. Consumers need no special case.

## Nesting

Only the deepest accepted target receives lifecycle callbacks, so nested targets
never handle one drop twice. The cost is that an ancestor stops indicating the
moment a descendant claims the drag. When a container has to stay highlighted
while its descendants activate in turn, render from the service instead and
leave drop handling to the descendants.

A descendant that answers `false` from `canDrop` is not accepted, so the drop
falls through to the nearest ancestor that does accept it. That is how a target
hands back a region it does not own, such as an edge band that belongs to the
enclosing container. Eligibility is sampled while the drag hovers and is not
asked again at the release, so the answer a target last gave is the one that
counts.

## Adopting browser-started drags

The browser starts drags on ordinary page content, such as a link or an image,
which registers no source and could not. An adoption lets a target take those
too. It names the kind of drag and supplies a predicate:

```js
export const WEB_LINK = {
  type: "web-link",
  match: ({ element }) => Boolean(element.closest("a[href]")),
};
```

```gjs
<div {{dDragAndDropTarget adopts=WEB_LINK onDrop=this.addLink}}></div>
```

From there it is an ordinary drag: the same callbacks, the same positions, the
same indicator. The adoption's `type` becomes `source.type`, so a monitor or
auto-scroll filters on it like any other type, and the native payload arrives on
`source.native` with the same reader API an external target hands you. Its
`items` list is always empty, because the handles go inert when `dragstart` ends.

Three rules are not guessable from the signature:

- **Adoption is resolved once for the page, not per target.** At `dragstart` the
  first live adoption whose predicate matches names the drag, and every target
  listing that name accepts it. Two adoptions sharing a name must therefore share
  a predicate. Declare one as a module constant and offer it from each target.
- **`adopts` without `accepts` refuses every registered source.** A target that
  named what it wants through `adopts` is not also asking for everything else on
  the page.
- **It covers only what the browser started on this page.** To take the same
  content dragged in from outside the window, pair the target with
  `dDragAndDropExternalTarget` on the same element.

Adoption deliberately leaves several drags alone: a registered source keeps its
own lifecycle, an element somebody else made draggable keeps its own drag, files
go to an external target, and a text selection is never adopted, including one
held inside an `input` or `textarea`. A predicate that throws is reported and
refuses, rather than deciding for the adoptions after it.

# dDragAndDropExternalTarget

Accepts payloads dragged in from another window or another application. It never
sees a drag that began on this page.

## Arguments

| Argument   | Type                                             | Purpose                                            |
| ---------- | ------------------------------------------------ | -------------------------------------------------- |
| `accepts`  | `"files" \| "html" \| "text" \| "urls"` or array | Which kinds engage the target. Omit to accept any. |
| `position` | `"before" \| "after" \| "inside"`                | Opts into resolving a position at all.             |
| `axis`     | `"vertical" \| "horizontal"`                     | Same, from the pointer against the midpoint.       |

It shares every kernel argument with the element target: `canDrop`,
`getDropEffect`, `getData`, `getIsSticky`, `indicator`, and the four lifecycle
callbacks.

Without `position` or `axis` the target is one destination rather than a slot:
callbacks receive `position: null` and the indicator is the single
`--drag-over-external` class. A registered external target carries
`data-drop-target-external`.

```gjs
<div
  {{dDragAndDropExternalTarget
    accepts=(array "urls" "text")
    onDrop=this.acceptLink
  }}
></div>
```

The payload exposes `types`, `containsFiles()`, `getFiles()`, `containsHTML()`,
`getHTML()`, `containsText()`, `getText()`, `containsURLs()` and `getURLs()`.
`items` and `getFiles()` are only populated at the drop.

**This is not the upload path.** A file dropped here does not enter upload
validation, progress, retries, or the upload record. Reach for it only when the
consumer genuinely wants the raw payload.

# dDragAndDropMonitor

Reacts to an element drag happening anywhere, without becoming a drop target.

| Argument      | Type                 | Purpose                                       |
| ------------- | -------------------- | --------------------------------------------- |
| `types`       | `string \| string[]` | Which drag types to watch. Omit to watch all. |
| `onDragStart` | `(event) => void`    | A watched drag began.                         |
| `onDrag`      | `(event) => void`    | Throttled, while it is in flight.             |
| `onDrop`      | `(event) => void`    | It was released.                              |

The element only anchors the modifier's lifecycle; a monitor is global.

# dDragAndDropAutoScroll

Scrolls a container while a drag hovers near its edge.

| Argument  | Type                                             | Purpose                            |
| --------- | ------------------------------------------------ | ---------------------------------- |
| `types`   | `string \| string[]`                             | Element drag types that engage it. |
| `accepts` | `"files" \| "html" \| "text" \| "urls"` or array | External kinds that engage it.     |
| `axis`    | `"vertical" \| "horizontal" \| "all"`            | Which direction to scroll.         |
| `target`  | `"element" \| "window"`                          | Scroll this element or the window. |

Element drags and external drags arrive through different adapters, so a surface
that takes both names both: `types` for the element side, `accepts` for the
external side.

# The dragAndDrop service

The service holds the in-flight drag as tracked state, so a surface can render
from it without wiring a callback.

| Member                   | Purpose                                           |
| ------------------------ | ------------------------------------------------- |
| `currentDrag`            | The in-flight element drag, or `null`.            |
| `currentExternalDrag`    | The in-flight external drag, or `null`.           |
| `isDragging`             | Whether either is in flight.                      |
| `accepts(types)`         | Whether the element drag's type is in `types`.    |
| `acceptsExternal(kinds)` | Whether the external drag carries one of `kinds`. |

`currentDrag` carries `type`, `data`, `element`, and `native` for an adopted
drag.

```gjs
<div class={{if (this.dragAndDrop.accepts "row") "is-drop-zone"}}></div>
```

Use the service to read and the monitor to respond. Rendering from monitor
callbacks means keeping state the service already owns.

Note that `accepts()` and `acceptsExternal()` treat an empty or missing filter
as matching nothing, because a caller that has not decided should not light up
for every drag. A target's `accepts` reads the other way: omitting it accepts
everything.

# dPointerDrag

Press, move, and release on one element, for a value that tracks the pointer.
It transfers nothing and has no targets.

| Argument          | Type                               | Purpose                                          |
| ----------------- | ---------------------------------- | ------------------------------------------------ |
| `onDragStart`     | `(event, info) => boolean \| void` | The gesture began. Returning `false` refuses it. |
| `onDrag`          | `(event, info) => void`            | The pointer moved.                               |
| `onDragEnd`       | `(event, info) => void`            | The gesture finished.                            |
| `onDragCancel`    | `(event, info) => void`            | It was interrupted rather than finished.         |
| `threshold`       | `number`                           | Pixels of movement before the gesture starts.    |
| `draggingClass`   | `string`                           | Class applied to the element while dragging.     |
| `bodyClass`       | `string`                           | Class applied to `document.body` while dragging. |
| `cancelCommits`   | `boolean`                          | Whether a cancel commits the last value.         |
| `stopPropagation` | `boolean`                          | Whether to stop the pointer events propagating.  |
| `touchAction`     | `TouchActionToken`                 | The `touch-action` to apply for the gesture.     |

Always handle `onDragCancel`. A gesture interrupted by the browser otherwise
leaves whatever `onDragStart` opened still open.

# DResizeSeparator

The default for resizing between two regions. `dResizeEdge` underneath keeps the
value math, the bounds and the keyboard operation; the separator adds the
accessibility contract on top: `role="separator"`, one tab stop, an
`aria-orientation`, and live `aria-valuenow` updates.

| Argument        | Type                                  | Purpose                                                                   |
| --------------- | ------------------------------------- | ------------------------------------------------------------------------- |
| `label`         | `string`, required                    | What the separator is called, already translated.                         |
| `axis`          | `"vertical" \| "horizontal"`          | `"vertical"` resizes height. Defaults to `"vertical"`.                    |
| `side`          | `"start" \| "end"`                    | The edge the handle sits on, naming the edge opposite the one that moves. |
| `measure`       | `Element` or `(separator) => Element` | The box being resized. Given this, it measures itself.                    |
| `value`         | `number` or `() => number`            | The current size, when it is not the measured extent.                     |
| `min` / `max`   | `number` or `() => number`            | Bounds. Override the measurement.                                         |
| `onResizeStart` | `() => void`                          | The gesture began.                                                        |
| `onResize`      | `(size) => void`                      | Throughout the gesture. Preview here.                                     |
| `onResizeEnd`   | `(size) => void`                      | Once at the end. Commit here.                                             |

`label` is required because a focusable `role="separator"` with no accessible
name is announced as a bare "splitter", which says nothing about what it
resizes.

```gjs
<DResizeSeparator
  @label={{i18n "sidebar.resize"}}
  @measure={{this.panelElement}}
  @onResizeEnd={{this.persistWidth}}
  @axis="horizontal"
/>
```

`onResizeEnd` also fires if the separator is destroyed mid-gesture, so anything
opened at the start still gets closed.

# dResizeEdge

The modifier underneath `DResizeSeparator`. Use it directly only when the
element and its separator semantics are already yours to provide.

| Argument        | Type                                     | Purpose                                          |
| --------------- | ---------------------------------------- | ------------------------------------------------ |
| `value`         | `number \| null` or a function, required | The current size.                                |
| `min` / `max`   | `number` or a function, required         | Bounds.                                          |
| `axis`          | `"vertical" \| "horizontal"`             | Which dimension is resized.                      |
| `side`          | `"start" \| "end"`                       | Which edge the handle sits on.                   |
| `bodyClass`     | `string`                                 | Class applied to `document.body` while resizing. |
| `onResizeStart` | `() => void`                             | The gesture began.                               |
| `onResize`      | `(size, meta) => void`                   | Throughout the gesture.                          |
| `onResizeEnd`   | `(size, meta) => void`                   | Once at the end.                                 |

# DResizeHandles

Renders the edges and corners of a two-dimensional box resize and reports
pointer geometry for the consumer to interpret.

| Argument                                                        | Type                          | Purpose                                                        |
| --------------------------------------------------------------- | ----------------------------- | -------------------------------------------------------------- |
| `directions`                                                    | `BoxDirection[]`              | Which of `n`, `ne`, `e`, `se`, `s`, `sw`, `w`, `nw` to render. |
| `handles`                                                       | `DResizeHandleDescriptor[]`   | Explicit handle descriptors with their payloads.               |
| `handleClass` / `draggingClass`                                 | `string`                      | Classes for the handles and the active gesture.                |
| `measure`                                                       | `MeasureTarget`               | The box the geometry is measured against.                      |
| `threshold`                                                     | `number`                      | Pixels of movement before a gesture starts.                    |
| `cancelCommits`                                                 | `boolean`                     | Whether a cancel commits the last value.                       |
| `stopPropagation`                                               | `boolean`                     | Whether to stop the pointer events propagating.                |
| `onResizeStart` / `onResize` / `onResizeEnd` / `onResizeCancel` | `(payload, dragInfo) => void` | The gesture lifecycle.                                         |

```js
@action
onResize(direction, { delta }) {
  if (direction.includes("e")) {
    this.width = Math.max(MIN, this.startWidth + delta.x);
  }
  if (direction.includes("s")) {
    this.height = Math.max(MIN, this.startHeight + delta.y);
  }
}
```

Do not give a two-dimensional box resize `role="separator"`. It has no single
`aria-valuenow` to report, so the role would describe a control that does not
exist.

# dSwipe

Reports a discrete directional flick with velocity, for touch surfaces that open
or dismiss something.

| Argument           | Type                     | Purpose                                   |
| ------------------ | ------------------------ | ----------------------------------------- |
| `onDidStartSwipe`  | `(state, event) => void` | The gesture began.                        |
| `onDidSwipe`       | `(state) => void`        | It progressed.                            |
| `onDidEndSwipe`    | `(state) => void`        | It completed.                             |
| `onDidCancelSwipe` | `(detail) => void`       | It was interrupted.                       |
| `enabled`          | `boolean`                | Whether the gesture is active.            |
| `lockBody`         | `boolean`                | Whether to lock body scrolling during it. |

Use `dPointerDrag` instead when a value must track the pointer continuously.
`dSwipe` answers "which way did they flick", not "where is the pointer now".

# dOnResize is not a gesture

`dOnResize` wraps `ResizeObserver`: it reports that an element's size changed,
and nobody resizes anything with it. The similar name is the trap. To let
someone change a size, use one of the resize primitives above.

# Accessibility

**A drag is not a keyboard interaction.** Every reorder surface has to pair the
drag with a keyboard path, and every resize between regions should use the
keyboard support already in `DResizeSeparator` or `dResizeEdge`.

**Announce the outcome, not the movement.** A completed reorder reports the
item's new visible position once through `a11y.announce()`. A no-op announces
nothing, and moving the pointer across drop indicators announces nothing.

**Do not add `aria-dropeffect` or `aria-grabbed`.** Both are deprecated and
neither makes a drag operable.

**A drag handle is decorative and stays outside the tab order,** because a
keyboard cannot operate it. The operable controls are the keyboard path beside
it.

**Keep the two paths' scopes honest.** They may legitimately differ: arrows may
move within one labeled list while a drag crosses between lists. The keyboard
path should follow the list the user is stepping through rather than silently
crossing a semantic boundary.

# Testing

Synthetic mouse events do not drive a native drag; they stall. Use the helpers.

In JavaScript tests, from
`discourse/tests/helpers/ui-kit/drag-and-drop-helper`:

| Helper                                        | Drives                                       |
| --------------------------------------------- | -------------------------------------------- |
| `simulateDrag(source, target, opts)`          | A registered source onto a target.           |
| `simulateUnsourcedDrag(source, target, opts)` | Browser-started page content onto a target.  |
| `simulateExternalDrag(target, opts)`          | A payload from outside the window.           |
| `externalDragOver` / `dragOver` / `startDrag` | A drag left hovering, without dropping.      |
| `dragEvent` / `dragEventNow`                  | One event, with or without a frame after it. |
| `centerOf` / `textTransfer` / `fileTransfer`  | Coordinates and payloads.                    |

Every synthetic drag event must carry finite `clientX` and `clientY`, which is
what `centerOf` is for.

In system specs, use `SystemHelpers#drag_and_drop`.

# dDraggable is deprecated

`dDraggable` raises `discourse.ui-kit.d-draggable` when instantiated. Use
`dPointerDrag`. It is not a drop-in: rename `didStartDrag`, `dragMove` and
`didEndDrag` to `onDragStart`, `onDrag` and `onDragEnd`, and add `onDragCancel`
so an interrupted gesture still finishes.
