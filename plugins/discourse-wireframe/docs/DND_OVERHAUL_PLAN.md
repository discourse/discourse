# Migrate container-drop-target + grid-overlay off raw native listeners onto ui-kit helpers

## Context

After Phase 3, the ui-kit DnD modifiers (`dDragAndDropSource`, `dDragAndDropTarget`, `dDragAndDropAutoScroll`) all run on Pragmatic DnD. But two plugin-internal pieces still use raw native event listeners:

1. **`plugins/discourse-wireframe/admin/assets/javascripts/discourse/modifiers/container-drop-target.js`** — wires `chromeElement.addEventListener("dragover" | "dragleave" | "drop", ...)` directly. Owns linear-DnD descriptor compute (stack / row / slot / grid-cell-leaf modes), grid-overlay defer, edge-band defer.

2. **`plugins/discourse-wireframe/admin/assets/javascripts/discourse/components/editor/grid-overlay.gjs`** — wires `gridEl.addEventListener("dragover" | "dragleave", ..., true)` on the layout's grid div. Owns the grid-level cursor → cell → descriptor compute, including the gap-between-cells insert-line path.

These cohabitations are what made the recent **drop-doesn't-fire bug** possible. PDND dispatches `source.onDrop` before `target.onDrop` in its chain; native bubble-phase drop listeners on chromes fire LATER. When the consumer's `source.onDrop` callback (`endDrag`) cleared shared dispatch state, the native listeners read cleared state and silently no-op'd. Splitting `endDrag` papered over it, but the architectural hazard remains for any future consumer.

## Architectural constraint (user-stated): PDND lives behind ui-kit

> "We shouldn't call PDND functions outside of the helpers or the service. The API surface are them. This enables us to keep our code library agnostic."

PDND is an implementation detail of the ui-kit modifiers and service. Plugins (and any other Discourse consumer) talk to PDND **only through** the ui-kit helpers — never via direct imports from `@atlaskit/pragmatic-drag-and-drop`. That gives us the option to swap PDND for something else later by changing only `frontend/discourse/app/ui-kit/`.

Today the modifier classes are the only PDND wrappers. That's fine for declarative template usage, but **container-drop-target.js needs imperative drop-target registration from inside a modifier's `modify()`** — and modifier-instantiates-modifier isn't an idiom in ember-modifier. So we extract the wrapping logic into module-level functions that both the modifier classes and other consumers can call.

## Ember integration — do we need a new service?

No new service. Existing surfaces are sufficient; the user's recollection ("we added one before") is the ui-kit `drag-and-drop` service added in `3640dd5366a`, still in place.

| Concern | Where it lives | Status |
|---|---|---|
| What's being dragged (`type`, `data`, source element) | `frontend/discourse/app/services/drag-and-drop.js` (ui-kit) | Keep |
| Dispatch state (`activeDropPreview`, `_lastDropPreview`, `dispatchActiveDrop`) | `services/wireframe.js` (plugin) | Keep — plugin-specific contract |
| Event lifecycle / preventDefault / stopPropagation | PDND, behind ui-kit | New — handed off here |

### Checked against the second candidate consumer

Audited `plugins/discourse-doc-categories`'s index editor DnD (~2,558 LOC across `index.gjs`, `link.gjs`, `section.gjs`, `lib/doc-index-utils.js`) — that's the other plugin the user plans to migrate to the new ui-kit DnD primitives.

What it does today:
- Raw HTML5 `addEventListener` per row (link, section).
- Per-element `is-drag-above` / `is-drag-below` / `is-dragging` CSS classes — exactly the smart-row indicator pattern `dDragAndDropTarget` already implements.
- Hit test via `isAboveElement(event)` — cursor-Y midpoint vs. element bounds. Identical to `dDragAndDropTarget`'s built-in `resolvePosition`.
- Drop dispatch is **synchronous, inline** — `this.args.onDrop(draggedLink, targetSection, isAbove)` fires immediately on drop, no descriptor preview state, no deferred call.
- No overlay / ghost — pure per-element CSS feedback.
- Two drag types (`"sections"` / `"items"`), batch multi-select tracked via parent-component fields (`#draggedLink`, `#draggedSection`, `batchDragType`).

What this tells us about API design:

1. **doc-categories maps directly onto `dDragAndDropTarget` as it stands today.** `accepts="link" | "section"`, `indicator=true` (their existing per-element CSS classes are the modifier's built-in `is-drag-above` / `is-drag-below`), `onDrop` callback receives `{position, source}` and dispatches inline. No new ui-kit surface needed for them.

2. **The wireframe's sticky-descriptor + single-overlay + dispatch-by-action-name contract would be overkill for doc-categories.** They don't need it; their drop semantics are deterministic at dragover time and they dispatch directly at drop. Promoting the dispatch contract to ui-kit now would be designing the API around the wireframe's needs alone, with doc-categories getting an abstraction it doesn't want.

3. **`isAboveElement` is a useful tiny utility but `dDragAndDropTarget` already does this via cursor-midpoint position math.** doc-categories' migration is "delete `lib/doc-index-utils.js`, set `indicator=true` and read `position` from the onDrop callback." We don't need to export a separate cursor-position helper.

**Decision:** keep the dispatch contract plugin-specific in `wireframe` for now. The doc-categories migration won't touch it. If a third consumer with similar complexity (overlay + delayed dispatch) materialises later, revisit then.

## Approach

### 1. Expose ui-kit's PDND wrappers as imperative helpers (in addition to modifiers), and fix two leaky behaviors at the abstraction level

In `frontend/discourse/app/ui-kit/modifiers/`, extract module-level helper functions that wrap PDND. The modifier classes call these helpers internally. Plugin / app code can also import the helpers when it needs imperative drop-target / draggable / auto-scroll setup outside a template.

**API surface principle:** PDND (`@atlaskit/pragmatic-drag-and-drop*`) is imported ONLY by the three ui-kit modifier files. Anything outside ui-kit — plugins, app code, tests — uses either the modifier (template-based) or the helper function (imperative). Preserves library-agnosticism.

**Cleanup model (lifetime-bound, not arg-bound):**
- The helper signature is `register…(element, getArgsRef) => cleanupFn` (or `register…(args, getArgsRef)` for auto-scroll). `getArgsRef` is a closure that returns the latest args. The helper registers PDND ONCE with stable wrapper callbacks that call `getArgsRef()` on every invocation; arg changes don't trigger re-registration.
- The returned `cleanupFn` is the ONLY teardown — caller calls it once when the element / consumer goes away. For modifier-based use, that's at `registerDestructor`. For grid-overlay's imperative use, that's at `willDestroy`.
- The modifier classes internally hold an args field that they update on each `modify()` call; the helper's wrappers read from that field via the closure. Net result: callers only deal with one cleanup, at destroy time.

**Source modifier hides PDND's source.onDrop ordering (no docs-as-insurance):**
- PDND dispatches `source.onDrop` BEFORE `target.onDrop` in the same drop event. That ordering is an implementation detail of PDND, not something a consumer should have to reason about.
- The source modifier's wrapper does the source-private cleanup (remove `is-dragging` class, clear `dragAndDrop.currentDrag`) inside PDND's source.onDrop. The CONSUMER's `onDrop` callback fires later via `queueMicrotask` — after PDND's full dispatch chain (`source.onDrop` → `target.onDrop` → `monitor.onDrop`) AND after any native bubble-phase listeners finish propagating.
- Net effect: from the consumer's POV, `onDrop` is a "drag finished, do cleanup" hook that fires when it's safe to clear any state.

**Why microtask, not just "let's hope timing works":**
- Per the HTML spec (perform a microtask checkpoint), microtasks queued during a task drain immediately after the task ends. The drop event's entire propagation (capture + target + bubble) is one synchronous task; our microtask is guaranteed to run after every listener for this drop.
- Microtasks fire FIFO. We schedule ours from PDND's source.onDrop, which fires FIRST in PDND's dispatch chain — so we're at the head of the microtask queue. Nothing the spec defines runs between the end of the drop task and our microtask that could touch the state we care about.
- Alternatives considered and rejected:
  - **PDND's `monitorForElements({onDrop})`** — fires synchronously after source + target in PDND's dispatch, but BEFORE native bubble-phase listeners on non-PDND elements. Insufficient during step 3's migration window (wireframe still has native chrome listeners until step 3 lands; step 1 must be safe in the interim).
  - **`requestAnimationFrame`** — overkill; introduces ~16ms visible lag for what should be near-instant cleanup.
  - **No deferral + doc warning** — what we have today. Leaks the ordering. The recent drop-doesn't-fire bug came from a consumer (wireframe.endDrag) tripping on this exact leak.
- Microtask choice also keeps us library-agnostic: if PDND is ever swapped, the "fires after current task" guarantee still holds — it's a JS event-loop spec, not a PDND feature.

**Documentation requirement:** the `queueMicrotask` call inside `registerDraggable`'s wrapped `onDrop` MUST carry an inline comment explaining:
- WHY the deferral exists (PDND dispatches source.onDrop before target.onDrop in the same task; consumer callbacks need to fire after target dispatch completes).
- WHAT spec guarantee makes it safe (microtask checkpoint at task end, per the HTML event-loop spec).
- WHY the consumer callback + payload are snapshotted before the microtask fires (modifier args can change across re-renders; we want the values from THIS drag).

The intent: anyone reading the code in 6 months understands this isn't a timing hack but a deliberate use of a spec guarantee.

**`d-drag-and-drop-target.js`** — export `registerDropTarget(element, getArgsRef) => cleanupFn` alongside the default-export modifier. Same `args` shape as the modifier (`accepts`, `canDrop`, `getData`, `getDropEffect`, `getIsSticky`, `onDragEnter`, `onDrag`, `onDragLeave`, `onDrop`, `indicator`, `axis`). Internally wraps `dropTargetForElements` with stable wrappers; applies the deepest-only filter; toggles the indicator class. The modifier's `modify()` becomes: save args to a field; on first run, call `registerDropTarget(element, () => this.#args)` and stash the cleanup.

**`d-drag-and-drop-source.js`** — same pattern: export `registerDraggable(element, getArgsRef) => cleanupFn`. Wraps PDND's `draggable`, applies the consumer-onDrop deferral described above, and the modifier calls it.

**`d-drag-and-drop-auto-scroll.js`** — same: export `registerAutoScroll(getArgsRef) => cleanupFn` (plus an element ref for element-scoped scrolling, or `target: "window"` for the window variant). Modifier calls it.

**Choosing modifier vs. helper:**
- Use the modifier `{{dDragAndDropTarget ...}}` when the element is in your own template. This is the common case — doc-categories, outline-panel, palette entries.
- Use `registerDropTarget(element, getArgsRef)` when you've captured the element ref imperatively (e.g., via `didInsert` on a sibling marker, or after walking the DOM). This is the case for the wireframe's grid-overlay (the grid div is owned by `wf-layout.gjs`, not grid-overlay's template) and for container-drop-target.js (which is itself a modifier consumed by block-chrome, so calling `registerDropTarget` from inside `modify()` is the natural path).

Files affected:
- `frontend/discourse/app/ui-kit/modifiers/d-drag-and-drop-source.js`
- `frontend/discourse/app/ui-kit/modifiers/d-drag-and-drop-target.js`
- `frontend/discourse/app/ui-kit/modifiers/d-drag-and-drop-auto-scroll.js`

Behavior change from outside: ONE — the source modifier's `onDrop` callback now fires after the full drop dispatch instead of before it. This is a visible improvement: consumers can do whatever they want in there (including clearing shared state) without race conditions. Update the integration tests that check ordering. Everything else is internal: same imports, same args shapes.

After this step, `@atlaskit/pragmatic-drag-and-drop*` is imported only by these three files (verifiable via grep).

### 2. `container-drop-target.js` → uses `registerDropTarget` from ui-kit

Replace the modifier's raw `chromeElement.addEventListener(...)` setup with a single `registerDropTarget(chromeElement, {...})` call. The modifier's `modify()` lifecycle stays the same shape: set up on `modify`, tear down via `registerDestructor`.

```js
import { registerDropTarget } from "discourse/ui-kit/modifiers/d-drag-and-drop-target";

// inside the modifier function:
const cleanup = registerDropTarget(chromeElement, {
  accepts: ["wf-block", "wf-palette-block"],
  indicator: false,  // we have our own descriptor-driven overlay
  canDrop: ({ source, input }) => {
    // 1. type filter (handled by `accepts` above; left here for any extra gate)
    // 2. grid-overlay defer — return false when cursor is in a nested
    //    `.wf-layout--grid` inside this chrome (the grid overlay owns it).
    // 3. edge-band defer — return false in the 12px outer band so drops
    //    near boundaries fall through to the parent container.
    // ...existing logic, reading cursor coords from `input`.
  },
  onDrag: ({ source, location }) => {
    // Build the descriptor and publish via `wireframe.setActiveDropPreview`.
    // Same `computeDescriptor` / `buildSlotChromeDescriptor` calls as today,
    // just reading `clientX/Y` and `shiftKey` from `location.current.input`
    // instead of a native DragEvent.
  },
  onDragLeave: () => {
    wireframe.clearActiveDropPreview();
  },
  onDrop: () => {
    wireframe.dispatchActiveDrop();
  },
});
```

Mode-specific behavior stays — the modifier's `mode` arg still picks between `"slot"` (single REPLACE landing → `buildSlotChromeDescriptor`), `"stack"` / `"row"` (sibling reorder → `computeDescriptor`), `"grid-cell-leaf"` (only `onDrop` matters, no dragover compute), and `"grid"` / `null` (no registration). The mode branches choose which callbacks the `registerDropTarget` call uses.

All `event.preventDefault()` / `event.stopPropagation()` go away — PDND handles them inside `registerDropTarget`.

The helper functions (`computeDescriptor`, `buildSlotChromeDescriptor`, `buildInsertDescriptor`, `buildInsideDescriptor`, `buildReplaceSlotDescriptor`, the validation predicates, the label / dispatch builders) all stay; only the entry point changes.

### 3. `grid-overlay.gjs` → uses `registerDropTarget` for the grid-level dragover

Replace the grid-div native listeners in `captureGridElement` with one `registerDropTarget(gridEl, {...})` call:

```js
import { registerDropTarget } from "discourse/ui-kit/modifiers/d-drag-and-drop-target";

// in captureGridElement, after locating gridEl:
this.#gridDropTargetCleanup = registerDropTarget(gridEl, {
  accepts: ["wf-block", "wf-palette-block"],
  indicator: false,
  onDragEnter: ({ source, location }) => this.#publishFromDrag(source, location),
  onDrag: ({ source, location }) => this.#publishFromDrag(source, location),
  onDragLeave: () => {
    this.#lastIntermediate = null;
    this.wireframe.setActiveDropPreview(null);
  },
  onDrop: () => this.wireframe.dispatchActiveDrop(),
});

// in willDestroy:
this.#gridDropTargetCleanup?.();
```

`#publishFromDrag(source, location)` is a thin wrapper: build the synthetic `event` shape the existing `_descriptorFromCursor(event, source)` expects (`{clientX, clientY, shiftKey}` from `location.current.input`), diff against `#lastIntermediate`, call `#publishUnified` on change. The descriptor-compute logic itself stays.

Empty cells stay as `dDragAndDropTarget` modifier instances in the template — they already go through ui-kit. PDND's deepest-only filter (inside `registerDropTarget`) ensures:
- Cursor over an empty cell → the cell's onDrag fires; the grid-div's onDrag is filtered out as not-deepest.
- Cursor in a gap between cells → only the grid-div is deepest. Its onDrag fires; insert-line descriptor path stays correct.
- Cursor over a slot chrome (after step 2's migration) → the chrome is deepest.

**Removed:** `_gridDragOverHandler`, `_gridDragLeaveHandler`, the `gridEl.addEventListener` / `removeEventListener` pairs in `captureGridElement` / `willDestroy`. The `#dragCache` / `#invalidateDragGeometry` stay — they cache geometry for the descriptor compute, orthogonal to event source.

### 4. Restore `wireframe.endDrag` to do the full drag-end cleanup

With the source modifier deferring consumer callbacks until after dispatch (step 1), `endDrag` is no longer racing with anyone. It can go back to doing the natural thing: clear ALL drag-related state, including `_lastDropPreview` and `activeDropPreview`. By the time `endDrag` runs (microtask after PDND's full dispatch chain), any target.onDrop has already consumed the descriptor — clearing it is just cleanup.

This undoes the surgery from the recent drop-doesn't-fire bug fix: we previously split `endDrag` so it skipped the shared dispatch fields. That split was a workaround for the leak; once the abstraction is fixed at the source, the split isn't needed.

Files affected:
- `plugins/discourse-wireframe/admin/assets/javascripts/discourse/services/wireframe.js` — restore the full `endDrag` cleanup; remove the comment about the dispatch-state separation.

### 5. Cleanup verification

Greps that should return zero matches in the plugin / app code after the migration:

```
grep -rn 'addEventListener("drag\|addEventListener("drop' plugins/discourse-wireframe/admin
grep -rn '@atlaskit/pragmatic-drag-and-drop' plugins/discourse-wireframe/
```

And verify PDND is imported only from the three ui-kit modifier files:

```
grep -rln '@atlaskit/pragmatic-drag-and-drop' frontend/discourse/app/ plugins/
```

→ should list only `d-drag-and-drop-source.js`, `d-drag-and-drop-target.js`, `d-drag-and-drop-auto-scroll.js`.

## Files affected

| File | Change |
|---|---|
| `frontend/discourse/app/ui-kit/modifiers/d-drag-and-drop-target.js` | Extract `registerDropTarget(element, getArgsRef)` named export; modifier class calls it. Args read via closure ref → no re-register on arg change. |
| `frontend/discourse/app/ui-kit/modifiers/d-drag-and-drop-source.js` | Extract `registerDraggable(element, getArgsRef)` named export; modifier class calls it. Consumer `onDrop` callback is deferred via `queueMicrotask` so it runs after PDND's full dispatch chain — hides the source.onDrop ordering inside the abstraction. |
| `frontend/discourse/app/ui-kit/modifiers/d-drag-and-drop-auto-scroll.js` | Extract `registerAutoScroll(getArgsRef)` named export. |
| `plugins/discourse-wireframe/admin/assets/javascripts/discourse/modifiers/container-drop-target.js` | Replace `addEventListener` plumbing with `registerDropTarget`. Lift `onDragOver` / `onDragLeave` / `onDrop` / `onLeafDrop` into the helper's callbacks. Move grid-overlay defer + edge-band defer into `canDrop`. Drop manual `preventDefault` / `stopPropagation`. ~787 LOC currently; expect ~-50 to -100 LOC net after removing event-plumbing boilerplate. |
| `plugins/discourse-wireframe/admin/assets/javascripts/discourse/components/editor/grid-overlay.gjs` | Replace `_gridDragOverHandler` / `_gridDragLeaveHandler` plumbing with one `registerDropTarget` call. Build synthetic event shape from `location.current.input` for the existing `_descriptorFromCursor`. |
| `plugins/discourse-wireframe/admin/assets/javascripts/discourse/services/wireframe.js` | Restore `endDrag` to its natural shape: clear ALL drag-related state, including `_lastDropPreview` / `activeDropPreview`. With the source modifier's deferral (step 1), `endDrag` no longer races with anyone, so the recent surgery to skip those fields can be undone. |

## Helpers / surfaces reused (no duplication)

- `registerDropTarget` / `registerDraggable` / `registerAutoScroll` — NEW exports from ui-kit, called by plugin code.
- `wireframe.setActiveDropPreview` / `clearActiveDropPreview` / `dispatchActiveDrop` — existing, unchanged.
- `wireframe.dragSource` — set by the source modifier's consumer callback (`block-chrome.gjs::handleDragStart` / `palette-entry.gjs::handleDragStart`), unchanged.
- `descriptorsEqual` (existing module-level helper in `grid-overlay.gjs`) — keeps powering the dragover diff after the migration.
- `computeDescriptor`, `buildSlotChromeDescriptor`, `buildInsertDescriptor`, `buildInsideDescriptor`, `buildReplaceSlotDescriptor`, validation predicates, label / dispatch builders — all stay in `container-drop-target.js`, called from the new helper callbacks instead of native event handlers.

## Out of scope (defer)

- Promoting the dispatch contract (`_lastDropPreview` / `activeDropPreview` / `dispatchActiveDrop`) into a shared ui-kit service. Wait until a second consumer exists.
- `@atlaskit/pragmatic-drag-and-drop-hitbox` adoption. Separate task.
- Migrating `grid-tile-drag.js` (resize handle, pointer events, not DnD).
- Migrating `outline-panel.gjs`'s reorder targets — already use `dDragAndDropTarget` (PDND-backed), no change needed.

## Verification

**Lint + tests:**
- `bin/lint --fix --recent`
- `bin/qunit plugins/discourse-wireframe/test/javascripts/` (expect 160 pass)
- `bin/qunit frontend/discourse/tests/integration/ui-kit/modifiers/drag-and-drop-test.gjs` (6)
- `bin/qunit frontend/discourse/tests/unit/services/drag-and-drop-test.js` (5)

**Manual smoke** — every dispatch semantic:
- Move card between cells in a grid (same grid).
- Move card across grids (different outlets).
- Swap (Shift+drag onto an occupied cell).
- Replace (Shift+drag from palette onto an occupied cell).
- Shift-insert via top / bottom / left / right edge zones in grid.
- Drag palette block into an empty cell.
- Drag palette block into a stack / row layout.
- Drag existing block into a stack / row layout sibling position.
- Fill slot (drop on a `wf:slot` chrome).
- Outline-panel row reorder.

**Edge cases:**
- Drag NEAR a container chrome's edge (12px band) — drop should land on the PARENT, not the chrome.
- Drag over a nested grid inside a stack layout — the grid overlay's descriptor should win.
- Drop in a grid gap (between cells, no element underneath) — should produce an insert-line descriptor.

**Architectural check (greps above):**
- No `addEventListener("drag/drop", ...)` in plugin code.
- No `@atlaskit/pragmatic-drag-and-drop` imports outside the three ui-kit modifier files.

## Risks

- **Helper extraction must preserve the modifier's current behavior byte-identically.** The modifier classes after this step should be thin wrappers around their helpers. Verify via the existing 6 integration tests, which exercise the modifier API.
- **Edge-band / grid-overlay defer in `canDrop`** — `canDrop` is called per event by PDND with the latest input. Performance should be fine (`getBoundingClientRect` + a few comparisons); cache via `#dragCache` from Phase 1 if a profile shows hot.
- **Synthetic event for `_descriptorFromCursor`** — currently expects `event.clientX/Y/shiftKey` from a native DragEvent. We construct a small object with those fields from `location.current.input`. Single point of adjustment, low risk.
- **Multiple PDND drop targets in the grid (grid-div, empty cells, slot chromes)** — need to verify the deepest-only filter resolves correctly. Existing tests cover the `dDragAndDropTarget` wrapper; since all three now go through `registerDropTarget`, they share the same filter.
- **`canDrop` for non-PDND consumers can no longer dynamically reject** — wait, this doesn't apply: PDND's canDrop IS dynamic per the type definition. Keeping as a note.

## Recommended commit boundaries

Three commits, each independently verifiable:

1. **`DEV: ui-kit — expose imperative DnD helpers + defer source onDrop`** — extracts `registerDropTarget` / `registerDraggable` / `registerAutoScroll` exports; modifier classes call them internally with arg-ref closures so no re-registration on arg change; the source modifier's consumer `onDrop` is deferred via `queueMicrotask` so it runs after PDND's full dispatch chain. Visible-from-outside change: the source's `onDrop` callback now fires after all drop dispatching (was: before). Integration test for the source's `is-dragging` toggle stays the same; any tests that asserted the old "source before target" timing get updated.
2. **`DEV: discourse-wireframe — restore endDrag to full cleanup`** — undo the dispatch-state-separation surgery on `endDrag`. With commit 1 in place, the race is gone; `endDrag` can clear everything in one go. Tiny commit, paired with commit 1's behavior.
3. **`DEV: discourse-wireframe — migrate container-drop-target + grid-overlay off raw native listeners`** — the bulk. container-drop-target.js uses `registerDropTarget`; grid-overlay's `_handleGridDragOver` / `_handleGridDragLeave` removed in favor of `registerDropTarget` on the grid div; manual `preventDefault` / `stopPropagation` deleted. Eliminates the last raw HTML5 DnD listeners in the plugin.

Estimated 2-3 days of focused work, mostly in commit 3. Commit 1 is the one to be careful with — it changes the source modifier's contract and the rest of the plan depends on it.
