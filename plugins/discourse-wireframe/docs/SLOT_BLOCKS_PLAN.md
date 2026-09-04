# Slot blocks: template-defined drop targets as first-class layout entries

## Context

We tried twice to give templates a shape (hero + 3 lays out one wide block + three tiles) and both attempts broke:

1. **`previewShape` only on the thumbnail** — applied template was a frame-only `3×2` grid, the thumbnail lied about the result.
2. **`args.slots` on the parent + a new slot UI in the grid overlay** — slot rects and real children competed as two positioning systems. The overlay grew a new `dDragAndDropTarget` per slot, which collided with the grid-level dragover handler painting the drop preview. Result: drags went "crazy".

The right shape (after talking it through) is: **a slot IS an entry.** Same drag-and-drop machinery, same resize handle, same chrome — no parallel state, no new drop targets in the overlay. The slot is a leaf block whose only job in the editor is to render a `+` placeholder at a positioned grid rect. Drop a block on the slot → the slot entry is replaced by the dropped block (which inherits the slot's `containerArgs.grid`). Delete a block that came from a slot → a slot is re-inserted at the same rect.

Templates write slot entries directly into `wf:layout.children` — applying "hero + 3" produces four `wf:slot` entries with `containerArgs.grid` matching the template's areas. The author fills them one by one; the layout's shape persists through fill/delete cycles.

## Approach

### 1. New block: `wf:slot`

**File**: `plugins/discourse-wireframe/assets/javascripts/discourse/blocks/wf-slot.gjs`.

```js
@block("wf:slot", {
  displayName: "Slot",
  category: "Layout",
  icon: "border-none",
  paletteHidden: true, // not in the palette — only created by templates
})
export default class WFSlot extends Component {
  <template>
    {{! Renders nothing on the live page. The editor's BlockChrome
        wraps the slot and switches into "slot empty" mode (the +
        placeholder UI) when it sees `blockName === "wf:slot"`. }}
  </template>
}
```

Why a registered block (rather than a synthetic entry the validator special-cases):

- Validator accepts leaf blocks freely — `wf:slot` passes validation without changes to `validateContainerChildren`.
- It serializes / deserializes naturally with the rest of the layout — no save-path branching.
- The chrome wrapping it gets the resize handle, drag handle, selectability, and outline row for free, because all of those are already keyed on entry presence, not block type.

### 2. Slot UI in the chrome

**File**: `plugins/discourse-wireframe/assets/javascripts/discourse/components/editor/block-chrome.gjs`.

When the wrapped block is `wf:slot` (`@blockName === "wf:slot"`), the chrome:

- Replaces the wrapped content (where `<@WrappedComponent />` normally renders) with a `<EditorEmptyCellPlaceholder>` — the same affordance the grid overlay already renders for unoccupied cells (the `+` button + palette picker). Extract the existing markup from `components/editor/grid-overlay.gjs:1005-1052` into a shared component so chrome and overlay both call it.
- Suppresses the toolbar's "delete" being misleading (delete on a slot is the same as on any block — it removes the entry).
- Keeps the resize handle so authors can resize the slot's rect across cells (same `gridTileDrag` modifier already in chrome).

The placeholder's "Pick a block" picker calls `wireframe.fillSlot({slotKey, blockName, previewArgs})` (new service action below).

### 3. Service: fill-on-drop + restore-on-delete

**File**: `plugins/discourse-wireframe/assets/javascripts/discourse/services/wireframe.js`.

Two new actions:

```js
@action
fillSlot({ slotKey, blockName, defaultArgs = {} }) {
  // 1. Locate the slot entry. Capture its containerArgs.grid.
  // 2. Replace it in-place with the new block entry. The new entry
  //    inherits the slot's containerArgs.grid and gets a marker
  //    `__fromSlot: true` on the entry (NOT in args — sits at the
  //    entry level next to `__stableKey`).
  // 3. Single _recordStructural / _publishStructuralChange.
}
```

`__fromSlot` is the recurrence hint. It's a `__`-prefixed entry property, which already follows the existing convention for editor-internal entry markers (`__stableKey`, `__failureType`, `__failureReason`). The save-path serializer (`serializeEntryForSave` in `lib/mutate-layout.js`) already strips `__`-prefixed fields, so this marker is editor-runtime only — it doesn't pollute persisted layouts.

```js
// Hooked inside the existing removeBlock action (lib/mutate-layout.js
// `removeEntry`), not as a new action — we want this behavior on
// EVERY delete path (toolbar delete, drag-out-and-drop, etc.).
//
// When removeEntry strips an entry that had `__fromSlot === true`,
// it also inserts a `wf:slot` entry at the same position with the
// same containerArgs.grid. One structural-undo entry: delete +
// restore land in the same publish.
```

This makes "drop replace, delete restore" symmetric. Cmd+Z after delete brings the block back (the existing undo system already handles that, independent of the restore mechanism — those are two layers).

Drop semantics:

- The block chrome's existing drop targets (sibling drop zones, inside drop zone) already route through `wireframe.moveBlock` / `insertBlock`. For drops onto a slot's chrome we want REPLACE, not insert-as-sibling. Add a `replacesSlot: true` predicate to the slot's chrome drop modifier — when the slot chrome receives a drop, it calls `replaceEntry(slotKey, droppedEntry)` instead of `insertEntryAt`. New helper in `mutate-layout.js`: `replaceEntry(layout, key, newEntry)` paralleling `replaceEntryInPlace`.

### 4. Templates write slot entries directly

**File**: `plugins/discourse-wireframe/assets/javascripts/discourse/lib/grid-templates.js`.

Each template declares its shape as a `grid-template-areas`-style string (the parser from the previous attempt's `parseGridAreas` is good — keep it). Adding `resolveTemplateLayout(template)` that returns:

```js
{
  args: { mode, columns, rows, gap, align, ... }, // frame
  slotEntries: [ // children to insert
    { block: "wf:slot", containerArgs: { grid: { column, row, align: "stretch", justify: "stretch" } } },
    ...
  ],
}
```

**Apply algorithm** (`applyGridTemplate` in the service):

- Always write the frame args (`columns`, `rows`, `gap`, `align`).
- **Frame-only template** (`12-column` — no `areas` string): do not touch children. The new grid frame may leave existing placements out of bounds; that's already handled by the existing `--out-of-bounds` warning + "Snap blocks into bounds" affordance in `inspector-layout-form.gjs`.
- **Template with slots**, where `n = existing children count`, `s = template slot count`:
  - `n === 0`: insert slot entries as children. Apply silently.
  - `0 < n ≤ s`: **preserve existing children, fit them into the template**. Walk children in document order, assigning each to the next slot — overwrite that child's `containerArgs.grid` with the slot's rect. Append `wf:slot` entries for the remaining `(s - n)` slots. Apply silently.
  - `n > s`: refuse. Surface inline as a disabled template chip with a tooltip "Your layout has more blocks than this template's cells". No destructive overwrite happens.

The "preserve and fit" path means dropping a hero-plus-three template on a layout with 2 children re-positions both children into the hero rect + the first bottom-row rect; the other two rects stay as slots. The author still recognises their content; the template just snaps them into the new shape.

No confirmation dialog needed — the worst case (`n > s`) is a no-op refusal. Everything else either has no content to lose or preserves what's there.

Template catalog (10 total — keep the 4 existing + 6 new):

| Name | Areas |
|---|---|
| 12-column | (frame only — no slots) |
| Hero + 3 | `hero hero hero` / `a b c` |
| Sidebar + main | `sidebar main main main` |
| Main + right sidebar | `main main main sidebar` |
| Two column | `a b` |
| 3 tiles | `a b c` |
| 4-card row | `a b c d` |
| Magazine | `lead lead aside` / `lead lead aside` |
| Hero + 2×2 | `hero hero` / `a b` / `c d` |
| Stacked sections | `a` / `b` / `c` |

### 5. What we don't need

- **No `args.slots` on `wf:layout`.** Reverted.
- **No new dragging affordances in the grid overlay.** The chrome already handles drops on positioned entries.
- **No validator changes.** `wf:slot` is a leaf block — `validateContainerChildren` is satisfied.
- **No live-page rendering changes.** A `wf:slot` on a published page renders nothing visible inside its grid cell, just as if the author left an empty positioned div there. Themes can `display: none` the `.block-wf-slot` class if they want to remove the slot's cell allocation in production.

## Files to add

- `plugins/discourse-wireframe/assets/javascripts/discourse/blocks/wf-slot.gjs` — the slot block (no-op render).
- `plugins/discourse-wireframe/assets/javascripts/discourse/components/editor/empty-cell-placeholder.gjs` — extracted `+` UI + palette picker, used by both `block-chrome.gjs` (for `wf:slot` entries) and `grid-overlay.gjs` (for auto-detected empty cells). Avoids duplicating the picker markup.

## Files to modify

- `plugins/discourse-wireframe/assets/javascripts/discourse/lib/mutate-layout.js` — add `replaceEntry(layout, key, newEntry)`. Extend `removeEntry` so that when the removed entry has `__fromSlot === true`, the returned layout includes a freshly-minted `wf:slot` entry at the same `containerArgs.grid`. This keeps the restore logic in one place rather than scattered across delete code paths.
- `plugins/discourse-wireframe/assets/javascripts/discourse/services/wireframe.js` — add `fillSlot({slotKey, blockName, defaultArgs})`. Rewrite `applyGridTemplate` per the apply-algorithm section above (frame-only vs. slot-template; preserve-and-fit when `0 < n ≤ s`; refuse when `n > s`).
- `plugins/discourse-wireframe/assets/javascripts/discourse/lib/grid-templates.js` — restructure each template with an optional `areas` string; export `resolveTemplateLayout(template)`. Add the 6 new entries.
- `plugins/discourse-wireframe/assets/javascripts/discourse/components/editor/block-chrome.gjs` — branch on `@blockName === "wf:slot"`: render the placeholder instead of `<@WrappedComponent />`, route drops to `replaceEntry`. Keep resize handle / drag handle / selection.
- `plugins/discourse-wireframe/assets/javascripts/discourse/components/editor/grid-overlay.gjs` — replace inline cell-picker markup with `<EmptyCellPlaceholder>`.
- `plugins/discourse-wireframe/assets/javascripts/discourse/components/editor/inspector-layout-form.gjs` — `TemplatePreview` thumbnail reads `resolveTemplateLayout(template)` to render slot rects (same as last attempt's `parseGridAreas` flow, but the parser lives in `grid-templates.js` now).
- `plugins/discourse-wireframe/plugin.rb` — `register_svg_icon "border-none"` is already there.
- `plugins/discourse-wireframe/config/locales/client.en.yml` — strings for the 6 new template names + a `slot.placeholder_label` ("Pick a block for this slot").
- `plugins/discourse-wireframe/assets/stylesheets/wireframe.scss` — `.wf-slot` chrome styling (same dashed amber as empty cells, but at the slot's full rect via `containerArgs.grid`).

## Existing primitives reused

- **`+` placeholder + palette picker**: `components/editor/grid-overlay.gjs:1005-1052` — extract verbatim.
- **`gridTileDrag` resize modifier**: `modifiers/grid-tile-drag.js` — slots get resize for free because chrome wraps them and `isGridCell && isSelected` is true.
- **`replaceEntryInPlace`**: `lib/mutate-layout.js` — model for the new `replaceEntry` helper.
- **`parseGridAreas`**: re-implement from last attempt (it was clean — only Phase B's wiring was bad).
- **`dialog.confirm` pattern**: `components/editor/inspector-layout-form.gjs:163-177` — model for "this will clear existing content".
- **`__`-prefixed entry markers**: `__stableKey`, `__failureType` set the precedent for `__fromSlot`. Strip path: `serializeEntryForSave` in `mutate-layout.js`.
- **`insertBlockAtCell` service action**: `services/wireframe.js:2871` — model for the structural-undo wrapping around `fillSlot`.

## Verification

End-to-end after `bin/rails server` is up:

1. `bin/lint --fix --recent` — clean.
2. `bin/qunit plugins/discourse-wireframe/test/javascripts/unit/lib/mutate-layout-test.gjs` — add cases:
   - `replaceEntry` swaps in a new entry at a key, preserves siblings.
   - `removeEntry` of an entry with `__fromSlot: true` returns a layout containing a `wf:slot` at the same `containerArgs.grid`.
   - `removeEntry` of an entry WITHOUT `__fromSlot` returns the same layout shape as before this change (no regression on the existing remove path).
3. Open the editor on a homepage with a registered layout. Select the `wf:layout`. Click the "Hero + 3" template chip.
   - Confirm the thumbnail matches what gets applied.
   - Confirm 4 `wf:slot` entries appear on the canvas, each rendering the `+` placeholder.
   - Confirm the hero slot spans 3 columns; the bottom row has 3 single-cell slots.
4. Click the hero slot's `+`, pick a `wf:cta-banner`. Confirm the slot is replaced by the cta-banner, sized to span the same 3 columns. The other 3 slots remain.
5. Delete the cta-banner via the toolbar. Confirm a slot reappears at the same rect — the layout is back to its post-template state.
6. Resize one of the bottom slots: drag its resize handle to span columns 2-3. Confirm the slot's `containerArgs.grid.column` becomes `"2 / 4"` and the slot's placeholder rect grows.
7. Drag an existing block onto a slot (not the palette — a real block already on the canvas). Confirm the dragged block lands in the slot (replace), the slot is removed, the original location of the dragged block becomes empty.
8. Apply a different template (e.g., "Magazine", which has 2 slots) to a layout that already has 2 blocks. Confirm both blocks are repositioned into the two magazine slots in document order; no slots are left empty. Apply a 1-cell template to a layout with 3 blocks — confirm the template chip is disabled with the "more blocks than cells" tooltip and no mutation happens.
9. Save the layout. Reload the page. Confirm slots persist as `wf:slot` entries in the saved JSON. Confirm the live page renders the filled cells normally and renders nothing visible (but allocates the grid cell) for empty slots.

## Decisions locked

- **Save semantics**: slots persist as `wf:slot` entries. Live page renders empty cells (no visible content; grid cell is still allocated by `containerArgs.grid`). Themes can `display: none .block-wf-slot` if they want production pages to collapse empty cells.
- **Apply-template behaviour**: no confirmation dialog. Frame-only templates leave children alone; slot templates fit existing children into the new slots (document order); templates with fewer cells than current content are refused inline.
- **Slot delete affordance**: the chrome's standard toolbar delete is the only way. One mental model — slot is a block.
