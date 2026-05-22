// @ts-check
import { modifier } from "ember-modifier";
// Absolute addon path: `grid-math` is in the universal bundle (its
// `parsePlacement` is called by the live-page `wf-layout.gjs`), this
// modifier is admin-only. Cross-bundle imports use absolute paths.
import {
  cellAt,
  parseSlotPlacement,
} from "discourse/plugins/discourse-wireframe/discourse/lib/grid-math";

/**
 * Pointer-event drag handler for grid tile overlays (Phase 7s.6).
 *
 * Two modes, distinguished by the element the user grabs:
 *
 *  - **Move** — pointerdown on the tile body. The tile follows the
 *     pointer, snapping to grid lines. On drop, the slot's
 *     `column` / `row` start values shift to the new cell while the
 *     span (end - start) is preserved.
 *  - **Resize** — pointerdown on the bottom-right `__resize-handle`.
 *     The tile's top-left stays put; the trailing edge expands /
 *     contracts to the pointer's cell.
 *
 * The ghost element (a `__ghost` sibling injected by the grid overlay)
 * is repositioned via inline `grid-column` / `grid-row` styles during
 * the move so the user sees the proposed destination snap to grid
 * lines in real time. CSS transitions on the ghost smooth the snap.
 *
 * Arguments (positional):
 *   1. `getGridElement` — function returning the actual grid container
 *      (the `wf-layout--grid` `<div>`), used to measure the current
 *      viewport rect on pointerdown and convert pointer coordinates →
 *      cell. Passed as a getter (not a direct element) so the modifier
 *      resolves the reference on pointerdown — by which time the
 *      overlay's `didInsert` has run — rather than at modifier setup
 *      time, when the parent's `didInsert` hasn't fired yet and the
 *      element would still be `null`.
 *   2. `placement` — the slot's current `{column, row}` strings.
 *   3. `columns` — number of grid columns.
 *   4. `rows` — number of grid rows.
 *   5. `getGhost` — function returning the ghost `<div>` element, or
 *      null when the overlay isn't currently rendering one.
 *   6. `onCommit({column, row})` — called once on pointerup with the
 *      new placement (as CSS Grid shorthand strings). The caller is
 *      responsible for routing the commit through the editor service.
 */
export default modifier(
  (element, [getGridElement, placement, columns, rows, getGhost, onCommit]) => {
    let mode = null;
    let originRect = null;
    let originCell = null;
    let originPlacement = null;
    let ghostEl = null;
    let pointerId = null;

    function onPointerDown(event) {
      if (event.button !== 0) {
        return;
      }
      const gridElement = getGridElement?.();
      if (!gridElement) {
        return;
      }
      // Resize handles live in two places: the grid overlay (`__tile-resize`,
      // for tile-overlay-based editing) and the block chrome itself
      // (`__resize-handle`, for the chrome-driven grid editor). Either
      // matches and puts the modifier into resize mode; anywhere else is
      // treated as a move grab on the tile body.
      const isResize = event.target.closest(
        ".wireframe-grid-overlay__tile-resize, .wireframe-block-chrome__resize-handle"
      );
      mode = isResize ? "resize" : "move";
      originRect = gridElement.getBoundingClientRect();
      originCell = cellAt(event, originRect, columns, rows);
      originPlacement = parseSlotPlacement({
        column: placement.column,
        row: placement.row,
      });
      // Auto-placed slots don't have a concrete starting cell to
      // anchor a span calculation against, so we treat the pointer's
      // starting cell as their origin.
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
      ghostEl = getGhost?.();
      if (ghostEl) {
        applyGhostStyle(ghostEl, originPlacement);
        ghostEl.classList.add("--visible");
      }
      pointerId = event.pointerId;
      element.setPointerCapture(pointerId);
      element.classList.add("--dragging");
      event.preventDefault();
      event.stopPropagation();
    }

    function onPointerMove(event) {
      if (!mode || !originRect) {
        return;
      }
      const cell = cellAt(event, originRect, columns, rows);
      const next = computeNextPlacement(
        mode,
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
    }

    function onPointerUp() {
      if (!mode) {
        return;
      }
      const next = element._veNextPlacement;
      if (next) {
        onCommit({
          column: formatLine(next.column),
          row: formatLine(next.row),
        });
      }
      cleanup();
    }

    function cleanup() {
      if (ghostEl) {
        ghostEl.classList.remove("--visible");
      }
      element.classList.remove("--dragging");
      if (pointerId != null) {
        try {
          element.releasePointerCapture(pointerId);
        } catch {
          // pointer was already released by the browser
        }
      }
      mode = null;
      originRect = null;
      originCell = null;
      originPlacement = null;
      ghostEl = null;
      pointerId = null;
      element._veNextPlacement = null;
    }

    element.addEventListener("pointerdown", onPointerDown);
    element.addEventListener("pointermove", onPointerMove);
    element.addEventListener("pointerup", onPointerUp);
    element.addEventListener("pointercancel", cleanup);

    return () => {
      element.removeEventListener("pointerdown", onPointerDown);
      element.removeEventListener("pointermove", onPointerMove);
      element.removeEventListener("pointerup", onPointerUp);
      element.removeEventListener("pointercancel", cleanup);
    };
  }
);

/**
 * Computes the new `{column, row}` placement given the drag mode,
 * the origin placement / cell, the current pointer cell, and the
 * grid bounds. Pure function — extracted so the math is testable.
 *
 * - **move**: shift start by (current - origin), preserve span.
 *     Result is clamped so the tile stays inside the grid.
 * - **resize**: keep start, extend end to current cell + 1.
 *     Resizing cannot shrink below a 1×1 span.
 *
 * @returns {{column: {start: number, end: number}, row: {start: number, end: number}}}
 */
function computeNextPlacement(mode, origin, originCell, cell, columns, rows) {
  if (mode === "move") {
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
  // resize
  const colEnd = clamp(cell.column + 1, origin.column.start + 1, columns + 1);
  const rowEnd = clamp(cell.row + 1, origin.row.start + 1, rows + 1);
  return {
    column: { start: origin.column.start, end: colEnd },
    row: { start: origin.row.start, end: rowEnd },
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
