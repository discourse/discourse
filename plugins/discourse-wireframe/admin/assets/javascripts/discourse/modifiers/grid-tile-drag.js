// @ts-check
import { modifier } from "ember-modifier";
import { parseSlotPlacement } from "discourse/blocks";
import { installPointerDrag } from "discourse/ui-kit/lib/pointer-drag";
// Absolute addon path: this admin-only modifier crosses into the plugin's
// universal `grid-math` bundle for the editor-only geometry helpers.
import {
  cellAt,
  computeSpanResize,
} from "discourse/plugins/discourse-wireframe/discourse/lib/grid-math";

/**
 * Pointer-event drag handler for grid tile overlays.
 *
 * Two modes, distinguished by whether a `direction` is supplied:
 *
 *  - **Move** — no direction; pointerdown on the tile body. The tile follows
 *     the pointer, snapping to grid lines. On drop, the slot's `column` / `row`
 *     start values shift to the new cell while the span (end - start) is
 *     preserved.
 *  - **Resize** — a `direction` (`n|s|e|w|ne|nw|se|sw`) names which edge /
 *     corner handle was grabbed. The opposite edge stays pinned; the grabbed
 *     edge(s) expand / contract toward the pointer's cell, clamping at the
 *     first occupied neighbour so a span never overlaps (see `computeSpanResize`).
 *
 * The ghost element (a `__ghost` sibling injected by the grid overlay) is
 * repositioned via inline `grid-column` / `grid-row` styles during the drag so
 * the user sees the proposed placement snap to grid lines in real time. CSS
 * transitions on the ghost smooth the snap.
 *
 * Arguments (positional):
 *   1. `getGridElement` — function returning the actual grid container
 *      (the `d-block-layout--grid` `<div>`), used to measure the current
 *      viewport rect on pointerdown and convert pointer coordinates → cell.
 *      Passed as a getter (not a direct element) so the modifier resolves the
 *      reference on pointerdown — by which time the overlay's `didInsert` has
 *      run — rather than at modifier setup time, when the parent's `didInsert`
 *      hasn't fired yet and the element would still be `null`.
 *   2. `placement` — the slot's current `{column, row}` strings.
 *   3. `columns` — number of grid columns.
 *   4. `rows` — number of grid rows.
 *   5. `getGhost` — function returning the ghost `<div>` element, or null when
 *      the overlay isn't currently rendering one.
 *   6. `onCommit({column, row})` — called once on pointerup with the new
 *      placement (as CSS Grid shorthand strings). The caller is responsible for
 *      routing the commit through the editor service.
 *   7. `direction` — resize handle direction (`n|s|e|w|ne|nw|se|sw`), or a
 *      falsy value for a move grab on the tile body.
 *   8. `getOccupied` — function returning a `Set` of cells (keyed `"row,col"`)
 *      occupied by OTHER entries in the grid (exclude this slot), used to clamp
 *      a growing span. Optional; defaults to no occupancy clamp.
 */
export default modifier(
  (
    element,
    [
      getGridElement,
      placement,
      columns,
      rows,
      getGhost,
      onCommit,
      direction,
      getOccupied,
    ]
  ) => {
    let mode = null;
    let originRect = null;
    let originCell = null;
    let originPlacement = null;
    let occupied = null;
    let ghostEl = null;

    return installPointerDrag(
      element,
      {
        onDown(event) {
          const gridElement = getGridElement?.();
          if (!gridElement) {
            return false;
          }
          // A resize handle supplies its edge/corner direction; the bare tile
          // body (no direction) is a move grab.
          mode = direction ? "resize" : "move";
          originRect = gridElement.getBoundingClientRect();
          originCell = cellAt(event, originRect, columns, rows);
          originPlacement = parseSlotPlacement({
            column: placement.column,
            row: placement.row,
          });
          // Auto-placed slots don't have a concrete starting cell to anchor a
          // span calculation against, so we treat the pointer's starting cell
          // as their origin.
          if (originPlacement.column.start == null) {
            originPlacement.column = {
              start: originCell.column,
              end: originCell.column + 1,
            };
          }
          if (originPlacement.row.start == null) {
            originPlacement.row = {
              start: originCell.row,
              end: originCell.row + 1,
            };
          }
          occupied = mode === "resize" ? (getOccupied?.() ?? null) : null;
          ghostEl = getGhost?.();
          if (ghostEl) {
            applyGhostStyle(ghostEl, originPlacement);
            ghostEl.classList.add("--visible");
          }
        },
        onMove(event) {
          if (!originRect) {
            return;
          }
          const cell = cellAt(event, originRect, columns, rows);
          const next =
            mode === "resize"
              ? computeSpanResize({
                  origin: originPlacement,
                  cell,
                  direction,
                  columns,
                  rows,
                  occupied,
                })
              : computeMovePlacement(
                  originPlacement,
                  originCell,
                  cell,
                  columns,
                  rows
                );
          if (ghostEl) {
            applyGhostStyle(ghostEl, next);
          }
          element._veNextPlacement = next;
        },
        onUp() {
          const next = element._veNextPlacement;
          if (next) {
            onCommit({
              column: formatLine(next.column),
              row: formatLine(next.row),
            });
          }
          cleanup();
        },
        onCancel() {
          cleanup();
        },
      },
      { draggingClass: "--dragging" }
    );

    function cleanup() {
      if (ghostEl) {
        ghostEl.classList.remove("--visible");
      }
      mode = null;
      originRect = null;
      originCell = null;
      originPlacement = null;
      occupied = null;
      ghostEl = null;
      element._veNextPlacement = null;
    }
  }
);

/**
 * Computes the new `{column, row}` placement for a MOVE drag: shift the start
 * by (current cell - origin cell), preserving the span, clamped so the tile
 * stays inside the grid. Pure function — extracted so the math is testable.
 * (Resize geometry lives in `computeSpanResize` in `grid-math`.)
 *
 * @returns {{column: {start: number, end: number}, row: {start: number, end: number}}}
 */
function computeMovePlacement(origin, originCell, cell, columns, rows) {
  const dCol = cell.column - originCell.column;
  const dRow = cell.row - originCell.row;
  const colSpan = origin.column.end - origin.column.start;
  const rowSpan = origin.row.end - origin.row.start;
  let colStart = origin.column.start + dCol;
  let rowStart = origin.row.start + dRow;
  colStart = clamp(colStart, 1, columns - colSpan + 1);
  rowStart = clamp(rowStart, 1, rows - rowSpan + 1);
  return {
    column: { start: colStart, end: colStart + colSpan },
    row: { start: rowStart, end: rowStart + rowSpan },
  };
}

function applyGhostStyle(ghost, placement) {
  ghost.style.gridColumn = `${placement.column.start} / ${placement.column.end}`;
  ghost.style.gridRow = `${placement.row.start} / ${placement.row.end}`;
}

function formatLine(track) {
  if (track.end <= track.start + 1) {
    return `${track.start}`;
  }
  return `${track.start} / ${track.end}`;
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}
