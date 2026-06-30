# Add row-height resize to grid layouts

## Context

The grid `layout` block already supports **column** track resizing: the editor renders
draggable gutter handles on interior vertical gridlines, and dragging one recomputes
per-column `fr` ratios stored as `columnFractions` (split-pane conserve — the grid has a
fixed width, so growing one column steals from its neighbour). Recent commits
(`821f1cb…`, `649be44…`) extracted the shared `DResizeHandles` + `d-pointer-drag`
primitives and refined this.

The matching **row** resize was left pending. This plan adds it.

**Key asymmetry (drives the whole design):** columns resize by conserving a fixed width,
but a grid has **no definite height** — rows render as `repeat(rows, minmax(80px, auto))`
and grow with content. `fr` row units can't redistribute (no free space to divide). So
row resize uses an **additive per-row min-height** model (confirmed with the user):
dragging a horizontal gutter handle raises the height *floor* of the row above it; the
grid grows taller; content can still push a row beyond its floor. Only the dragged row
changes — no stealing from neighbours.

## Data model

New layout arg **`rowSizes`** (parallels `columnFractions`, but holds px floors, not fr
ratios). An array of length = row count; `0`/unset for a row means "use the default
floor". Distinct name from the existing singular `rowHeight` arg (the uniform default
template) on purpose.

## Changes

### 1. Schema + render — `frontend/discourse/app/blocks/builtin/layout.gjs`
- Add `rowSizes` arg next to `rowTemplate`/`rowHeight`: `{ type: "array", itemType: "number", default: [] }`. No `ui` block (mirrors `columnFractions`, which is edit-driven, not inspector-exposed).
- In `containerStyle` (the `mode === "grid"` branch), build `gridTemplateRows` with precedence: raw `rowTemplate` > `rowSizes` (per-row floors) > `repeat(rows, rowHeight)`. For the `rowSizes` case, emit one track per row: `size > 0 ? minmax(${size}px, auto) : ${rowHeight}` joined by spaces (so unset rows fall back to the `rowHeight` arg, and customised `rowHeight` still composes). Normalise the array to the live row count first (see helper below) so it can't desync from `rows` — same guarantee the column path gives via `normalizeFractions`.

### 2. Normalisation helper — `frontend/discourse/app/lib/blocks/-internals/grid-placement.js`
- Add `normalizeRowSizes(sizes, count)` next to `normalizeFractions`. Same shape, but defaults a missing/invalid/non-positive entry to `0` (= "use default floor"), not `1`. Export it from `frontend/discourse/app/lib/blocks/index.js` alongside `normalizeFractions`.

### 3. Resize math — `plugins/discourse-wireframe/assets/javascripts/discourse/lib/grid-math.js`
- Add `resizeRowHeights(currentSizes, rowIndex, basisPx, deltaPx, { minPx = 24, stepPx = 8, rows } = {})`. Pure function, mirrors `resizeColumnFractions`'s placement in the file. Additive: `next = clamp(basisPx + deltaPx, minPx, Infinity)` snapped to `stepPx`. Returns a fresh array of length `rows` (filled from `currentSizes`, `0` for unset) with `result[rowIndex] = next`. No split-pane / proportional branch — height isn't conserved, so only the dragged row changes.

### 4. Persistence — `plugins/discourse-wireframe/admin/assets/javascripts/discourse/lib/grid-manipulator.js`
- Add `resizeRows({ gridKey, sizes })` mirroring `resizeColumns` (lines 403–424): locate entry, `recordStructural` → `replaceEntryInPlace` writing `args.rowSizes = sizes` → `publishStructuralChange`. A deterministic resize, no decider.
- In `syncDeclaredToUsage` (lines 486–522): mirror the `columnFractions` renormalisation block for rows — when `effective.rows !== declared.rows` and `rowSizes` is present, pad/truncate it to `effective.rows` (via `normalizeRowSizes`) so a drop that grows the grid extends `rowSizes` with default (`0`) entries.

### 5. Overlay UI — `plugins/discourse-wireframe/admin/assets/javascripts/discourse/components/editor/grid-overlay.gjs`
Mirror the column-track block (handles getter at ~332–378, handlers at ~388–473):
- **`get rowHandles()`** — guard `this.isCollapsed || this.rows < 2 → []`. For each interior line `2..rows`, walk **columns** `1..columns`, merging contiguous columns where no child spans across that row line into runs (the row analogue of `spansAcross`: `row.start < line && row.end > line && column.start <= col && column.end > col`). Each descriptor: `payload: line - 2` (0-indexed row-above), `class: "wireframe-grid-track-handle wireframe-grid-track-handle--row"`, `style: trustHTML(\`grid-row: ${line}; grid-column: ${runStart} / ${runEnd + 1};\`)`.
- **`onRowResizeStart(rowIndex)`** — get grid el, `#readRowHeights(el)` (parse `getComputedStyle(el).gridTemplateRows`), validate `rowIndex` in range, `selectGrid()`, stash `#rowResize = { gridEl, basisPx: pxHeights[rowIndex], nextSizes: null }`.
- **`onRowResize(rowIndex, dragInfo)`** — `nextSizes = resizeRowHeights(currentRowSizes, rowIndex, basisPx, dragInfo.delta.y, { rows: this.rows })`; preview by setting `--d-block-layout-rows` to the built template string (`nextSizes.map(s => s > 0 ? \`minmax(${s}px, auto)\` : rowHeightFallback).join(" ")`, where `rowHeightFallback = this.gridEntry?.args?.rowHeight || "minmax(80px, auto)"`).
- **`onRowResizeEnd()` / `onRowResizeCancel()`** — commit via `commitRowSizes(next)` / remove the `--d-block-layout-rows` inline override. Mirror the column versions exactly.
- **`commitRowSizes(sizes)`** — `this.wireframe.gridManipulator.resizeRows({ gridKey: this.args.gridKey, sizes })`.
- Template (~after the column `<DResizeHandles>` at 1872–1879): add a second `<DResizeHandles @handles={{this.rowHandles}} ...>` wired to the row handlers, with a comment describing horizontal gutter handles persisted as `rowSizes`.

### 6. Styling — `plugins/discourse-wireframe/assets/stylesheets/admin/wireframe-chrome.scss`
Extend the `.wireframe-grid-track-handle` block (~2751–2786). The base `::before` is a 2px vertical stroke; the `--column` modifier already exists. Refactor the shared hover rule so thickness is per-axis, then add `--row`:
- Move the `width: 4px` growth out of the shared `&:hover::before, &.--dragging::before` (leave only `opacity: 1` there) into `&--column` (`width`) and `&--row` (`height`).
- `&--row { height: 12px; align-self: start; flex-direction: column; transform: translateY(calc(-50% - var(--d-block-layout-gap, 0rem) / 2)); cursor: ns-resize; touch-action: none; &::before { width: auto; height: 2px; } &:hover::before, &.--dragging::before { height: 4px; } }`. `flex-direction: column` flips the cross axis so `align-items: stretch` stretches the `::before` to full width (a horizontal hairline).

## Files touched
- `frontend/discourse/app/blocks/builtin/layout.gjs` (schema + render)
- `frontend/discourse/app/lib/blocks/-internals/grid-placement.js` + `…/blocks/index.js` (helper + export)
- `plugins/discourse-wireframe/assets/javascripts/discourse/lib/grid-math.js` (math)
- `plugins/discourse-wireframe/admin/assets/javascripts/discourse/lib/grid-manipulator.js` (persist + sync)
- `plugins/discourse-wireframe/admin/assets/javascripts/discourse/components/editor/grid-overlay.gjs` (handles + handlers)
- `plugins/discourse-wireframe/assets/stylesheets/admin/wireframe-chrome.scss` (handle styling)

## Tests (mirror the column equivalents)
- **grid-math** — `plugins/discourse-wireframe/test/javascripts/unit/lib/grid-math-test.js`: `resizeRowHeights` — grow, clamp at `minPx`, snap to `stepPx`, only the dragged index changes, returns full-length array.
- **grid-placement** — `frontend/discourse/tests/unit/lib/blocks/grid-placement-test.js`: `normalizeRowSizes` (length coercion, `0` default for invalid/missing).
- **layout render (core)** — `frontend/discourse/tests/integration/components/blocks/layout-merged-cell-test.gjs` (or a sibling): `rowSizes` produces the expected `--d-block-layout-rows` (set rows → `minmax(Npx, auto)`, unset → `rowHeight` fallback); `rowTemplate` still wins.
- **manipulator (service)** — `plugins/discourse-wireframe/test/javascripts/unit/services/wireframe-test.gjs`: `resizeRows` persists `rowSizes` and is undoable; `syncDeclaredToUsage` pads `rowSizes` when a drop grows `rows`.
- **overlay rendering** — `plugins/discourse-wireframe/test/javascripts/integration/components/grid-overlay-rendering-test.gjs`: `rowHandles` renders `--row` handles, breaks runs at a spanning cell, and yields none when `rows < 2` / collapsed (per the "editor overlay needs a rendering smoke test" rule — unit tests never mount the overlay).

## Verification
1. `bin/qunit plugins/discourse-wireframe/test/javascripts/unit/lib/grid-math-test.js` and the manipulator/overlay/render test files above.
2. `bin/lint --fix` the touched JS/GJS/SCSS.
3. Manual (editor): create a grid layout, enter edit mode, hover an interior horizontal gridline → a `ns-resize` hairline appears; drag down → the row above grows, the grid gets taller, neighbours unaffected; release → `args.rowSizes` persists; undo restores; reload renders the taller row; a cell spanning two rows breaks the handle run at that line.
4. Confirm the live (non-editor) page renders the resized row heights from `rowSizes` (no editor chrome required — it's a plain `grid-template-rows` value).
