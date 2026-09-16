# Promote the empty grid cell into core as a "merged cell"

## Context

Empty spanning regions in a grid (a hero rail, a sidebar) are held by `wf:cell`
— the *only* plugin-side block, a pseudo-block filtered out of `children`
everywhere content is reasoned about. Two facts shape the design:

1. **Every persisted empty cell is a merge of ≥2 base cells.** Single-cell
   empties are never persisted — the overlay derives them geometrically. The
   persisted thing is always a *merged* region → "merged cell" is the accurate
   name (and good UX: merge base cells into one empty region, then drop a block
   into it; a *filled* span is just a block with a span).
2. **The grid container is the core `layout` block**, whose renderer paints an
   empty grid area only because a child entry exists to wrap.

Keep empty cells as **first-class child entries** ("uniform cells") and **move
the block into core** as `layout-merged-cell` (a named export in `layout.gjs`,
so it reads as part of the layout family). This keeps the non-overlap invariant
single + automatic, makes empty cells drag/resize/span via the existing chrome,
needs only a small core render change (live-path collapse), and reduces the old
"wart" to one `isMergedCell` predicate + one `contentCells` helper.

Pre-release: **no migration**. Single-cell empties stay derived.

### This is a refresh — what changed under the original plan
The resize-handle work shipped since this plan was first written, invalidating
two of its assumptions (verified against current code):
- **`resizeSlot` no longer grows the grid** (growth is drop-only). The original
  "mint a 1×1, then `resizeSlot` it to its span" path for `mergeCells` is dead.
  → `mergeCells` now does a **direct spanning insert** (below).
- The resize affordance is now the shared **`d-resize-handles`** component +
  `d-pointer-drag` modifier (the old `grid-tile-drag` is deleted). Q3's merge
  handle builds on these, and an existing merged-cell *entry* resizes for free
  via block-chrome's `<DResizeHandles>` (gated on `isGridCell`).
- `DEFAULT_GRID_COLUMNS/ROWS` constants now exist (use them in new code).

## Decisions (resolved with the product owner — still hold)
- **Q3 ships now**: a merge/span handle on the empty-cell tile creates a merged
  region from blank space.
- **Empty cells collapse outside an editing/preview context** (no ~80px band for
  live visitors).
- **The UX asymmetry (1×1 derived vs ≥2 persisted) is resolved by Q3, not a
  separate signifier** — the merge handle sits on every empty tile.

## Naming
- Core block: **`layout-merged-cell`** (`layout-` prefix = layout-family, not a
  standalone primitive). `displayName: "Merged cell"`, `category: "Layout"`,
  `icon: "border-none"`, `paletteHidden: true`. Class/export `LayoutMergedCell`.
- Predicate `isMergedCell(entry)` = `blockNameOf(entry) === "layout-merged-cell"`;
  content-only helper `contentCells(children)` (both exported from `grid-math.js`).

## Phase 1 — Core block + registration (plugin-agnostic; NO editor terms)
- `frontend/discourse/app/blocks/builtin/layout.gjs`: add a named export beside
  `Layout`:
  ```js
  @block("layout-merged-cell", { displayName: "Merged cell", category: "Layout",
    icon: "border-none", paletteHidden: true })
  export class LayoutMergedCell extends Component {
    <template>{{! Claims its grid area; renders nothing. }}</template>
  }
  ```
  Doc by mechanism only (an empty positioned region a grid layout wraps; themes
  target `[data-block-name="layout-merged-cell"]`). No `:has()`.
- `frontend/discourse/app/blocks/builtin/index.js`: `export { LayoutMergedCell } from "./layout";`
  (freeze-block-registry auto-registers it).

## Phase 2 — Live-path collapse (the one core render change)
A merged cell must contribute **zero footprint** to live visitors but hold its
space in the editor. The ~80px band is the ROW (`minmax(80px,auto)` floor), so a
row that exists *only* for merged cells must not be declared on the live path.
- In `layout.gjs`: inject `@service blocks`; a `renderedChildren` getter returns
  all children in the editor but **filters out `layout-merged-cell`** children
  when `!this.blocks.showGhosts`. Feed that same set to `gridDimensions` (so a
  merged-only row isn't counted) AND iterate it in the template (so the wrapper
  isn't emitted). A row shared with content is unaffected.
- Signal: **`this.blocks.showGhosts`** (VERIFIED: `services/blocks.js`, backed by
  `debugHooks.isGhostBlocksEnabled`, `true` when the editor is active, already
  used by core `block-head.gjs`). Core-generic; do NOT add a plugin signal.
- Keep `gridDimensions` itself context-free — the caller picks the child set.
- `"layout-merged-cell"` is a *core* block name, so this check is plugin-agnostic.

## Phase 3 — Rename + de-wart (replace every `wf:cell`)
Add `isMergedCell` + `contentCells` to `grid-math.js`; replace every literal.
Current sites (re-verify lines at build time):
- **Mints** → `layout-merged-cell`: `grid-math.js` `reflowChildrenIntoCells`
  (~201); `wireframe.js` `#reflowIntoCells` (~2993) + `removeBlock`/
  `#shouldRestoreAsCell` restore (~1173); `grid-templates.js` `resolveTemplateLayout` (~192).
- **Filters/predicates** → `isMergedCell`/`contentCells`: `grid-math.js`
  `syncContentToArrayOrder` (~236/251); `wireframe.js` `#contentChildren` (~2954),
  `#shouldRestoreAsCell` guard (~3629); `grid-manipulator.js` `placeInCell`/
  `moveIntoCell` guards (~182/228); `container-drop-target.js` (~274);
  `block-chrome.gjs` `isEmptyCell` (~865).
- Minter must stamp **no own `args`** (`{}` ok; non-empty throws `validateBlockArgs`
  — the block declares no args schema; placement lives in `containerArgs.grid`).
- Delete `assets/.../blocks/wf-cell.gjs`. In `pre-initializers/register-starter-blocks.js`
  remove ONLY the `WFCell` import + registration (**keep the file** — it also
  registers WFCtaActions/WFCtaCard).
- Tests: re-point `wf:cell` fixtures/keys (`grid-math-test.js`, `grid-drop-test.js`,
  `grid-templates-test.js`, `wireframe-test.gjs`, `drop-target-nesting-test.gjs`).
- Comment-only: `api-initializers/wireframe.js`, `walk-layout.js`, `editor-empty-drop-placeholder.gjs`.
- Grep `wf:cell|wf-cell|WFCell|isWfCell` after — a stray one = silent split-brain.
- `decideGridDrop`/`computeShiftPlan`/`clampGridSlotPlacements`/`isGridCellEntry`/
  `resizeSlot` are already cell-name-agnostic (key on `containerArgs.grid`/`entryKey`) — no change.

## Phase 4 — `mergeCells` / `splitCell` (the spanning-insert redesign)
`resizeSlot` no longer grows and the decider only lands 1×1, so route a **direct
spanning insert** through the **shared occupancy primitive** (not a bespoke
bypass, not the full decider):
- **Export `rectIsFree(children, rect, excludeKey)` from `grid-drop.js`** (built on
  the existing private `slotCoveringCell` — generalize it to a rect). Occupancy
  stays single-sourced; `mergeCells` and the decider share it.
- `mergeCells({ gridKey, rect })` (in `grid-manipulator.js`): inside one
  `recordStructural` — `rectIsFree` check (refuse on overlap) → `insertEntryAt` a
  `layout-merged-cell` entry with the spanning `containerArgs.grid` → `syncDeclaredToUsage`
  (grows declared to fit) → `selectInsertedEntry`.
- `splitCell({ cellKey })`: `removeEntry` + `syncDeclaredToUsage`; the overlay
  re-derives the uncovered 1×1s. Document "1×1 stays derived".
- **Resize-to-1×1 dissolve**: when an empty merged cell is resized to 1×1, `splitCell`
  it instead of persisting a degenerate entry. Guard test.
- **Guard the new ops**: extend the "drop-action coverage" guard to introspect
  `gridManipulator`'s prototype, whitelisting `mergeCells`/`splitCell` with a note
  that they validate via the shared `rectIsFree`. Add conservation + occupancy
  parity tests (mergeCells onto an occupied span refuses, same verdict as the decider).

## Phase 5 — Q3: merge handle on empty-cell tiles
The empty-cell tile in `grid-overlay.gjs` (`.wireframe-grid-cell` from `emptyCells`)
has no drag affordance today. Add one, reusing the resize machinery:
- Attach `<DResizeHandles>` (or the `d-pointer-drag` modifier) to the empty tile,
  distinct handle class from the column-track handles.
- `onResizeStart`: origin = the tile's 1×1 rect; capture occupancy (siblings) +
  the grid rect + the ghost (`getGridElement`, the `.wireframe-grid-ghost`).
- `onResize`: `cellAt(event, gridRect, cols, rows)` → `computeSpanResize({origin,
  cell, direction, columns, rows, occupied})` → paint the ghost.
- `onResizeEnd`: `gridManipulator.mergeCells({ gridKey, rect: next })`. The new
  entry then gets normal selection/resize chrome (block-chrome `isGridCell`).
- An *existing* merged-cell entry resizes for free via block-chrome's `<DResizeHandles>`.

## Phase 6 — FILL into a merged cell (one path, not two)
Today a drop onto an empty cell can route two ways: the decider (overlay) treats
a `containerArgs.grid` occupant as SWAP/REPLACE, while `placeInCell`/`moveIntoCell`
replace-in-place (the new block inherits the cell's span — the *correct* result).
Reconcile so both agree: teach `decideGridDrop` that an `isMergedCell` occupant is
**FILLable** (the drop consumes the merged cell; the block inherits its rect), so
the overlay path and the `placeInCell`/`moveIntoCell` path produce the same outcome.
Keep `placeInCell`/`moveIntoCell` (they already inherit the span correctly).

## Critical files
- Core: `frontend/discourse/app/blocks/builtin/layout.gjs` (+ block + live-collapse),
  `.../builtin/index.js`, `assets/javascripts/discourse/lib/grid-drop.js` (export `rectIsFree`).
- Rename surface (Phase 3 list): `grid-math.js`, `services/wireframe.js`,
  `grid-manipulator.js`, `grid-templates.js`, `container-drop-target.js`,
  `block-chrome.gjs`, `blocks/wf-cell.gjs` (delete), `register-starter-blocks.js`.
- New ops: `grid-manipulator.js` (`mergeCells`/`splitCell`).
- Q3: `grid-overlay.gjs`.

## Verification
- `bin/qunit plugins/discourse-wireframe/test/javascripts` green (run **targeted**
  modules via `--standalone --filter` — the full-suite standalone stalls in this
  env; the inspector-stub fix already unblocked it) + core block tests.
- New tests: `layout-merged-cell` registers + renders; live-collapse (a merged-only
  row is absent when `!showGhosts`, present when `showGhosts`); `mergeCells` refuses
  an occupied rect + grows declared; `splitCell` + resize-to-1×1 dissolve;
  FILL-into-merged-cell consumes + inherits span; conservation battery unchanged.
- `bin/lint --fix` on every touched file; grep clean of `wf:cell`.
- Live smoke (two-grid): template with an empty rail → live render shows no band,
  editor shows the held space; delete a multi-cell block → footprint stays as a
  merged cell; merge-drag an empty cell → spanning region; drop into it → fills +
  inherits span; saved JSON has `layout-merged-cell`, zero `wf:cell`.

## Notes
- Large, multi-phase; land phase-by-phase keeping the suite green.
- After approval, archive a copy into `plugins/discourse-wireframe/docs/` (per the
  long-plan convention) — can't be done from plan mode.
- Key change from the original draft: `mergeCells` is a direct spanning insert
  validated by the shared `rectIsFree` (NOT mint-1×1-then-resize, which the
  no-grow `resizeSlot` killed). It doesn't route `decideGridDrop` (which only lands
  1×1), but occupancy stays single-sourced, preserving the no-overlap invariant.
