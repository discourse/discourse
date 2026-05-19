# Visual-editor DnD overhaul — quick wins → descriptor consolidation → PDND-backed core primitives

## Context

After the collapsed-grid fixes shipped, the visual editor's DnD code is ~3500-4500 LOC across:

- `grid-overlay.gjs` (1515 LOC) — admin component, owns the grid-internal DnD pipeline.
- `container-drop-target.js` (791 LOC) — admin modifier, owns the linear (stack/row/slot) DnD pipeline.
- `grid-tile-drag.js` (224 LOC) — resize-handle drag, separate from the DnD modifiers.
- `drop-preview.gjs` (61 LOC) — single shell-mounted overlay.
- `outline-panel.gjs` — outline-list reordering.
- ~25 DnD-related methods on `services/visual-editor.js`.

The audit surfaced **two pain points**:

1. **Maintainability.** Two parallel descriptor pipelines coexist. The *linear* pipeline (`container-drop-target.js`) embeds a `{action, args}` dispatch payload in its descriptor; `service.dispatchActiveDrop()` runs the action by name. The *grid* pipeline (`grid-overlay.gjs`) carries no dispatch payload; it mirrors a label-only descriptor to the service, keeps its own `_lastDropPreview` slot, and dispatches via a custom switch on `descriptor.kind` / `variant`. Two state slots, two descriptor shapes, two dispatch tables. Tracing any single gesture means reading both files. The recent "drop duplicates instead of moves" bug was hard to diagnose precisely because of this divergence.

2. **Perceived responsiveness.** Editor DnD feels laggy on top of the architectural complexity:
   - `dropPreview` is `@tracked`; every `dragover` writes to it unconditionally — 60 Hz re-renders during stationary hover.
   - The overlay positions via `top` / `left` (forces layout + paint) rather than `transform` (compositor-only).
   - 2-3 `getBoundingClientRect()` / `getComputedStyle()` reads per dragover — synchronous layout flushes.
   - `dDragAndDropTarget` toggles CSS indicator classes per dragover in bubble phase.
   - No rAF batching.
   - No auto-scroll — tall layouts on small viewports stall at the canvas edge.

## Goals

Two simultaneous outcomes, equally important:

1. **Best DnD experience in the visual editor.** Smooth, responsive, no jank. One descriptor pipeline. Auto-scroll, eventual a11y on the horizon.
2. **Best reusable DnD infrastructure in Discourse core.** A clean, PDND-backed modifier + service API in `ui-kit` that any other plugin or core feature can pick up. The visual editor is the proving ground for this infra, but the infra outlives the plugin's use of it.

The plugin is currently the only consumer of `dDragAndDropSource` / `dDragAndDropTarget` across Discourse (greps confirmed: 2 / 3 consumer files all under `plugins/discourse-visual-editor/`). That gives us licence to **redesign the core API freely** rather than preserve its byte-identical surface. The integration test in `frontend/discourse/tests/integration/ui-kit/modifiers/drag-and-drop-test.gjs` gets rewritten to match the new contract.

## Phase 1 — Quick perceived-perf wins (1 day, no library, no architecture change)

Three small changes, immediate visible crispness, zero risk. Independent of Phases 2/3.

**Changes:**

- **`drop-preview.gjs`**: switch overlay positioning from `top: <y>px; left: <x>px;` to `transform: translate3d(<x>px, <y>px, 0);` + keep `width`/`height` for size. Promotes the overlay to its own compositor layer; reposition no longer triggers layout/paint. Add `will-change: transform` while the overlay is mounted with a non-null preview.

- **`grid-overlay.gjs setDropPreview`**: shallow-compare incoming descriptor against `this.dropPreview` before the tracked write. Compare `kind`, `column.start/end`, `row.start/end`, `line`, `variant`, `_invalid`, `_collapsedRect` coords. Skip the assignment if unchanged. Eliminates redundant re-renders during stationary hover.

- **`grid-overlay.gjs`**: cache `gridRect` (from `getBoundingClientRect`) and `isCollapsed` for the lifetime of a single drag. Capture on the first dragover; invalidate on `window` `resize` and `scroll`; clear on drop / dragend. Avoids 2-3 sync layout reads per dragover.

**Files modified:**
- `plugins/discourse-visual-editor/admin/assets/javascripts/discourse/components/editor/drop-preview.gjs`
- `plugins/discourse-visual-editor/admin/assets/javascripts/discourse/components/editor/grid-overlay.gjs`

## Phase 2 — Descriptor consolidation (3-4 days, no library)

Goal: **one descriptor shape, one state slot, one dispatch path** for both grid and linear DnD.

The linear contract today is the right one: descriptor carries an embedded `dispatch: {action, args}` payload, and `service.dispatchActiveDrop()` looks up `service[action]` and calls it with `args`. We extend this contract to the grid pipeline so grid dispatches go through the same channel.

**Grid descriptor generators (`_slotDescriptorForZone`, `_cellDescriptorForZone` in `grid-overlay.gjs`)** — embed a `dispatch` field at hit-test time. Mapping:

| Descriptor | dispatch |
|---|---|
| `rect` / `swap` | `{action: "swapSlotPlacements", args: {slotKeyA, slotKeyB}}` |
| `rect` / `replace` | `{action: "replaceSlot", args: {targetSlotKey, sourceSlotKey}}` |
| `rect` / `move` + palette | `{action: "insertBlockAtCell", args: {gridKey, blockName, defaultArgs, column, row}}` |
| `rect` / `move` + ve-block | `{action: "moveBlockToCell", args: {gridKey, sourceKey, column, row}}` |
| `line-row` / `line-column` | `{action: "insertWithShift", args: {gridKey, dropCell, direction, sourceKey \| paletteBlockName, paletteDefaultArgs}}` |

**Single state slot.** `grid-overlay.gjs` writes directly to `service.setActiveDropPreview(descriptor)`. No more local `_lastDropPreview` field on the overlay, no more `_mirrorToActivePreview`. Service's `_lastDropPreview` is the single source of truth.

**Geometry pre-stamped on the descriptor in viewport coords** (matching `container-drop-target.js` today) — no more grid-relative → viewport conversion at the consumer.

**Drop handlers become one-liners.** Empty cells' `onDrop` and the grid-cell-leaf `onLeafDrop` both become:
```js
event => { visualEditor.dispatchActiveDrop(); visualEditor.endDrag(); }
```
Delete: `applyCellDrop`, `applySlotDrop`, `_dispatchDrop`, `_dispatchInsertWithShift`, `_mirrorToActivePreview`, `_unifiedKindFor`, `_labelFor`, `_sourceDisplayName`, `_slotKeyAtPlacement`, the local `_lastDropPreview` field and `setDropPreview` action — all in `grid-overlay.gjs`.

**Document the unified contract** at the top of `container-drop-target.js`: every drop descriptor is `{geometry, kind, validity, label, dispatch: {action, args}, [optional grid-specific fields]}`.

**Service surface stays the same** for dispatch endpoints — they already exist. The `setDropPreview` / `clearDropPreview` / `getLastDropPreview` / `registerGridOverlay` / `unregisterGridOverlay` routing methods become deletable (no callers after the consolidation).

**Files modified:**
- `plugins/discourse-visual-editor/admin/assets/javascripts/discourse/components/editor/grid-overlay.gjs` (~400 LOC reduction)
- `plugins/discourse-visual-editor/admin/assets/javascripts/discourse/modifiers/container-drop-target.js` (~20 LOC)
- `plugins/discourse-visual-editor/admin/assets/javascripts/discourse/services/visual-editor.js` (delete dead routing methods, ~50 LOC)

## Phase 3 — PDND-backed core primitives + best-fit API redesign (5-7 days)

Goal: rewrite the ui-kit DnD modifiers and service against [Pragmatic Drag and Drop](https://atlassian.design/components/pragmatic-drag-and-drop/about), free to redesign the public API. Plugin consumers migrate to the new API.

### 3a. Deps go in core, not plugin

PDND is published as ESM under Apache-2.0. Discourse's pnpm workspace shares `frontend/discourse/`'s dependencies with all packages including plugins, so the deps live there:

- `frontend/discourse/package.json` — add `@atlaskit/pragmatic-drag-and-drop` (~5 KB) and `@atlaskit/pragmatic-drag-and-drop-auto-scroll` (~3 KB).
- Confirm Embroider resolves the imports from plugin code.

### 3b. Redesigned modifier + service API in `frontend/discourse/app/ui-kit/`

Free to break the existing API surface. Aiming for PDND's conceptual model with Ember-idiomatic ergonomics.

**`d-drag-and-drop-source` (Source modifier)**:

```hbs
{{dDragAndDropSource
  type="ve-block"            {{! was "kind" — aligns with PDND's "type" }}
  data=(hash blockKey=@blockKey outletName=@outletName)
                                   {{! or getInitialData=(fn this.getData) for dynamic }}
  dragPreview=this.chromeEl  {{! element ref for the drag image }}
  canDrag=this.canDrag       {{! NEW: synchronous gate, return false to block start }}
  onDragStart=this.onStart   {{! callback receives {source, input} }}
  onDrop=this.onEnd          {{! renamed from onDragEnd; matches PDND }}
  getDropEffect=this.effect  {{! NEW: "copy"|"move"|"link" per drag, optional }}
}}
```

**`d-drag-and-drop-target` (Drop-target modifier)**:

```hbs
{{dDragAndDropTarget
  accepts=(array "ve-block" "ve-palette-block")
                                   {{! array or single string }}
  canDrop=this.canDrop       {{! ({source, input, element}) => boolean }}
  getData=this.getDropData   {{! optional, returns target-side metadata }}
  getIsSticky=this.sticky    {{! NEW: PDND's sticky drop-target semantics }}
  onDragEnter=this.onEnter
  onDrag=this.onDrag         {{! PDND: only fires when drag data changes, NOT every mousemove }}
  onDragLeave=this.onLeave
  onDrop=this.onDrop
  indicator=true             {{! optional smart-row indicator (was implicit) }}
  axis="y"                   {{! "x" / "y", drives indicator + auto-position }}
}}
```

**`d-drag-and-drop-auto-scroll` (NEW Auto-scroll modifier)**:

```hbs
{{!-- Attached to a scroll container; auto-scrolls that element when a compatible drag is in flight. --}}
<div class="visual-editor-canvas"
  {{dDragAndDropAutoScroll types=(array "ve-block" "ve-palette-block") axis="vertical"}}
>

{{!-- Attached to <body> (or the document root) for window auto-scroll. --}}
{{dDragAndDropAutoScroll target="window" types=this.acceptedTypes}}
```

Wraps `autoScrollForElements` / `autoScrollWindowForElements` from `@atlaskit/pragmatic-drag-and-drop-auto-scroll/element`. `types` filters which drag types trigger the scroll. Putting auto-scroll on a *modifier attached to the scroll container* (rather than a top-level shell setup) keeps the API declarative, reusable, and localizes the cleanup to component teardown.

**`dragAndDrop` service (`frontend/discourse/app/services/drag-and-drop.js`)** — rewire to PDND's monitor:

```js
@service dragAndDrop;
// tracked: dragAndDrop.currentDrag = {type, data, source: <element>} | null
// tracked: dragAndDrop.isActive = boolean
// method: dragAndDrop.accepts(typeOrTypes) — supports string or array
```

Backed by `monitorForElements({onDragStart, onDrop})` set up once at service init. Same public-getter shape as today but with `type` instead of `kind`.

### 3c. Migration of plugin consumers (5 files)

Touch each consumer once to switch `kind` → `type`, adopt `canDrag` / `canDrop` / `getDropEffect` where they sharpen behavior, and use the new auto-scroll modifier where useful:

- `block-chrome.gjs` — drag handle: `kind` → `type`, add `canDrag` (refuse if block is locked / not editable), add `getDropEffect="move"` for clarity.
- `palette-entry.gjs` — palette tile: `kind` → `type`, add `getDropEffect="copy"`.
- `outline-panel.gjs` — outline rows: `kind` → `type` on both source and target.
- `container-drop-target.js` modifier — still owns its own listeners but reads `visualEditor.dragSource.type` (was `.kind`). Update one field name throughout.
- `grid-overlay.gjs` — same renames, post-Phase-2 surface.

Mount `dDragAndDropAutoScroll target="window"` once at the editor shell (a small additive change in `shell.gjs`), so auto-scroll lights up window scroll when a `ve-block` / `ve-palette-block` drag is in flight.

### 3d. Test contract rewrite

`frontend/discourse/tests/integration/ui-kit/modifiers/drag-and-drop-test.gjs` gets rewritten against the new API. Test names preserved where the semantic still holds:

- source + target handshake fires onDrop with source data
- type discriminator gates compatibility (was "kind discriminator")
- source toggles is-dragging during the drag
- smart row mode resolves position from cursor midpoint
- nested targets — innermost accepting target wins drop
- NEW: canDrag short-circuits dragstart
- NEW: canDrop short-circuits drop
- NEW: getDropEffect propagates to the dataTransfer effect
- NEW: auto-scroll engages while a matching type is in flight

The unit test (`tests/unit/services/drag-and-drop-test.js`) gets renamed assertions for `type` and `accepts`.

## Out of scope (defer)

- `@atlaskit/pragmatic-drag-and-drop-hitbox` (closest-edge / `attachInstruction`) — clean refactor target for `container-drop-target.js`'s `computeDescriptor` and friends (~200 LOC). Doesn't help responsiveness; bundle with a future linear-DnD cleanup.
- `pragmatic-drag-and-drop-flourish` (drop-success animation) — polish, defer.
- Keyboard / a11y DnD (`pragmatic-drag-and-drop-live-region` + Atlassian's keyboard pattern) — separate phase, separate scope. Real a11y win but not in this overhaul.
- `grid-tile-drag.js` (resize handle) — uses raw pointer events, not the DnD modifiers. Unaffected by all phases.

## Verification

**After Phase 1:**
- `bin/lint --fix --recent` + `bin/qunit plugins/discourse-visual-editor/test/javascripts/` — all 160 tests pass.
- Manual: drag a card around a 6×2 grid. Overlay glides smoothly. DevTools Performance: dragover handler self-time visibly reduced; far fewer `dropPreview` invalidations.

**After Phase 2:**
- Same automated tests pass.
- Manual smoke of every dispatch semantic in both grid and stack/row modes: swap (Shift+drag), replace, shift-insert (edge zones), move-to-empty-cell, move-into-container, fill-slot, outline-panel reorder.
- Grep confirms `_lastDropPreview` exists only on the service.

**After Phase 3:**
- `bin/qunit frontend/discourse/tests/integration/ui-kit/modifiers/drag-and-drop-test.gjs` — all rewritten tests pass.
- `bin/qunit plugins/discourse-visual-editor/test/javascripts/` — all editor tests pass.
- Manual: tall layout in a small viewport. Drag a card past the canvas edge — window auto-scroll engages. Drag from palette across a long page — same.
- DevTools Performance: PDND's rAF batching visible — one `onDrag` callback per frame, not 3-4.
- Confirm no plugin or core file outside the migrated set still imports the old API (no `kind=` on a DnD source/target site).

## Risks

- **Rewriting ui-kit modifiers and changing the public API.** Mitigation: only this plugin consumes them today (verified by grep). The integration test rewrite captures the new contract. Land Phase 3 in its own PR for isolated review/revert.
- **PDND's `onDrag` only fires on drag-data change, not per mousemove.** The smart-row position-indicator logic (toggling `is-drag-above` / `is-drag-below` on cursor crossing midpoint) needs an additional `pointermove` listener attached *inside* the modifier (since PDND's stock callbacks won't suffice). Validate against the rewritten integration test's smart-row case. Highest-risk part of Phase 3.
- **Descriptor consolidation in Phase 2 changes `dispatchActiveDrop`'s payload variants.** Dispatch endpoints already exist; we're just routing to them by name. Full qunit pass + the manual smoke matrix above. Revert is one commit.
- **`pragmatic-drag-and-drop` is ESM-only.** Embroider handles ESM in Discourse's stack. Smoke-test the production build after adding the dep.
- **Auto-scroll attached to `<body>` via a modifier needs careful placement.** The body element isn't typically the place we attach modifiers in Discourse. If awkward, fall back to a service-method API: `dragAndDrop.enableWindowAutoScroll({types, axis})` returning a cleanup. Either way the *interface* is declarative.

## Recommended commit boundaries

- **1 commit** Phase 1 (transform + diffing + caching). Title: `DEV: discourse-visual-editor — quick DnD perf wins`.
- **2-3 commits** Phase 2 (split between "extend grid descriptors with embedded dispatch" + "route all grid drops through dispatchActiveDrop, delete redundant glue").
- **3-4 commits** Phase 3:
  - `DEV: core — add Pragmatic DnD deps`
  - `DEV: ui-kit — redesign d-drag-and-drop modifiers on Pragmatic DnD`
  - `DEV: ui-kit — add d-drag-and-drop-auto-scroll modifier`
  - `DEV: discourse-visual-editor — migrate to redesigned DnD API + window auto-scroll`

## Files at a glance

- **Phase 1** (plugin only, 2 files): `drop-preview.gjs`, `grid-overlay.gjs`.
- **Phase 2** (plugin only, 3 files): `grid-overlay.gjs` (major), `container-drop-target.js` (minor), `services/visual-editor.js` (dead-code removal).
- **Phase 3** (core + plugin):
  - Core: `frontend/discourse/package.json`, `app/ui-kit/modifiers/d-drag-and-drop-source.js`, `d-drag-and-drop-target.js`, NEW `d-drag-and-drop-auto-scroll.js`, `services/drag-and-drop.js`, integration test + unit test.
  - Plugin: `block-chrome.gjs`, `palette-entry.gjs`, `outline-panel.gjs`, `container-drop-target.js`, `grid-overlay.gjs`, `shell.gjs`.
