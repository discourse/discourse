// @ts-check
// Imports from `./entry-key` (not `./mutate-layout`) so the universal
// bundle doesn't pull in the rest of mutate-layout's editor-only
// helpers. `parsePlacement` exported from this file is called by the
// live-page `ve-layout.gjs` block, so grid-math itself must stay
// universal — even though `computeShiftPlan` below is editor-only.
// Tree-shaking should keep `computeShiftPlan` out of the universal
// bundle when no universal consumer imports it.
import { entryKey } from "./entry-key";

/**
 * Pure helpers for the grid editor (Phase 7s). All functions
 * operate on plain data — no DOM access — so they're trivially
 * unit-testable.
 *
 * The grid is 1-indexed (matching CSS Grid's `grid-column` / `grid-row`
 * line numbering). A cell at column C, row R is referred to as
 * `{column: C, row: R}` in the API.
 *
 * Slot placement strings follow CSS Grid shorthand:
 *  - `"1 / 4"` — start at line 1, end at line 4 (spans 3 columns).
 *  - `"2"` — start at line 2, span 1.
 *  - `"auto"` — let CSS Grid auto-place.
 *
 * The parser is conservative: anything it doesn't recognise becomes
 * `{start: null, end: null}` so the editor falls back to auto-placement
 * rather than corrupting the user's data.
 */

/**
 * @typedef {{start: number|null, end: number|null}} Track
 * @typedef {{column: Track, row: Track}} SlotPlacement
 */

/**
 * Parses a slot's `column` / `row` arg strings into start / end line
 * numbers. Returns `{start: null, end: null}` for auto / span / unknown
 * placements.
 *
 * @param {Object} args
 * @returns {SlotPlacement}
 */
export function parseSlotPlacement(args) {
  return {
    column: parseTrack(args?.column),
    row: parseTrack(args?.row),
  };
}

/**
 * Reads grid placement out of a child entry's `containerArgs`. `ve:layout`
 * namespaces per-parent-mode placement hints under a top-level key
 * (`containerArgs.grid` for grid mode); this helper centralises that
 * access so callers don't reach into the namespace structure directly,
 * and future modes can be added without rewriting every consumer.
 *
 * @param {Object} [containerArgs]
 * @returns {SlotPlacement}
 */
export function parsePlacement(containerArgs) {
  return parseSlotPlacement(containerArgs?.grid);
}

/**
 * Parses a single CSS Grid line shorthand. Examples:
 *
 *  - `"1 / 4"` → `{start: 1, end: 4}`
 *  - `"2"` → `{start: 2, end: 3}` (single-line span 1)
 *  - `"auto"` / `""` / undefined → `{start: null, end: null}`
 *
 * @param {*} raw
 * @returns {Track}
 */
export function parseTrack(raw) {
  if (typeof raw !== "string") {
    return { start: null, end: null };
  }
  const value = raw.trim();
  if (!value || value === "auto" || value.startsWith("span")) {
    return { start: null, end: null };
  }
  const parts = value.split("/").map((s) => s.trim());
  const startNum = Number(parts[0]);
  if (!Number.isInteger(startNum) || startNum < 1) {
    return { start: null, end: null };
  }
  if (parts.length === 1) {
    return { start: startNum, end: startNum + 1 };
  }
  const endNum = Number(parts[1]);
  if (!Number.isInteger(endNum) || endNum <= startNum) {
    return { start: startNum, end: startNum + 1 };
  }
  return { start: startNum, end: endNum };
}

/**
 * Formats a track as a CSS Grid shorthand string suitable for writing
 * to `args.column` / `args.row`. Returns `"auto"` for null-valued
 * tracks so the serialised arg stays predictable.
 *
 * @param {Track} track
 * @returns {string}
 */
export function formatTrack(track) {
  if (!track || track.start == null) {
    return "auto";
  }
  if (track.end == null || track.end <= track.start + 1) {
    return `${track.start}`;
  }
  return `${track.start} / ${track.end}`;
}

/**
 * Computes the set of `(row, column)` cells occupied by the given
 * slots. Cells are keyed as `"R,C"` strings for cheap Set lookup.
 *
 * Explicitly-placed slots fill their declared cell rectangle. Slots
 * with auto placement are assigned to the next free cell in document
 * order — an approximation of CSS Grid's auto-flow that's good enough
 * to surface "+" placeholders only where authors haven't already
 * placed content.
 *
 * @param {Array<Object>} slots - Child entries of a grid layout.
 *   Reads each entry's `containerArgs.grid.column` / `.row`.
 * @param {number} columns
 * @param {number} rows
 * @returns {Set<string>}
 */
export function computeOccupation(slots, columns, rows) {
  const occupied = new Set();
  const autoSlots = [];

  for (const slot of slots ?? []) {
    const placement = parsePlacement(slot.containerArgs);
    if (placement.column.start != null && placement.row.start != null) {
      fillRect(occupied, placement, columns, rows);
    } else {
      autoSlots.push(slot);
    }
  }

  // Approximate CSS Grid auto-flow: walk the grid in row-major order,
  // assign each auto-placed slot to the first unoccupied cell. We
  // iterate by index rather than `for...of` because the loop variable
  // is unused — eslint flags the convenience binding otherwise.
  let cursor = nextFreeCell(occupied, columns, rows, { row: 1, column: 1 });
  for (let i = 0; i < autoSlots.length; i++) {
    if (!cursor) {
      break;
    }
    occupied.add(cellKey(cursor.row, cursor.column));
    cursor = nextFreeCell(occupied, columns, rows, advance(cursor, columns));
  }
  return occupied;
}

/**
 * Returns the list of unoccupied cells as `{column, row}` objects.
 * Convenience wrapper for the overlay's `+` placeholders.
 *
 * @param {Set<string>} occupied
 * @param {number} columns
 * @param {number} rows
 * @returns {Array<{column: number, row: number}>}
 */
export function unoccupiedCells(occupied, columns, rows) {
  const cells = [];
  for (let row = 1; row <= rows; row++) {
    for (let column = 1; column <= columns; column++) {
      if (!occupied.has(cellKey(row, column))) {
        cells.push({ column, row });
      }
    }
  }
  return cells;
}

/**
 * Resolves the cell `{column, row}` under a pointer event, given the
 * grid container's bounding rect. Used by the drag handlers in
 * Phase 7s.6 to compute snap targets.
 *
 * @param {{clientX: number, clientY: number}} event
 * @param {DOMRect} gridRect
 * @param {number} columns
 * @param {number} rows
 * @returns {{column: number, row: number}}
 */
export function cellAt(event, gridRect, columns, rows) {
  const x = event.clientX - gridRect.left;
  const y = event.clientY - gridRect.top;
  const cellWidth = gridRect.width / columns;
  const cellHeight = gridRect.height / rows;
  const column = clamp(Math.floor(x / cellWidth) + 1, 1, columns);
  const row = clamp(Math.floor(y / cellHeight) + 1, 1, rows);
  return { column, row };
}

/**
 * Returns `true` when two slot placements occupy any shared cells. Both
 * placements must be EXPLICIT (their `column.start` / `row.start` set);
 * auto placements report `false` because CSS Grid's auto-flow handles
 * them without colliding into explicitly-placed neighbours.
 *
 * Used by chrome decoration to flag visually-overlapping blocks so the
 * author notices an accidental resize past a neighbour.
 *
 * @param {SlotPlacement} a
 * @param {SlotPlacement} b
 * @returns {boolean}
 */
export function placementsOverlap(a, b) {
  if (
    a?.column?.start == null ||
    a?.row?.start == null ||
    b?.column?.start == null ||
    b?.row?.start == null
  ) {
    return false;
  }
  return (
    a.column.start < b.column.end &&
    b.column.start < a.column.end &&
    a.row.start < b.row.end &&
    b.row.start < a.row.end
  );
}

/**
 * Computes the slot mutations needed to insert a new occupant at an
 * edge of `dropSlotKey`, cascading existing slots away in the relevant
 * direction until an empty cell absorbs them. Returns `null` if the
 * shift can't fit (cascade walks off the grid, or a shifted slot
 * collides with a non-cascadable neighbour).
 *
 * Edge / direction mapping:
 *
 *  - `"left"` → source lands at dropSlot's leftmost cell; dropSlot and
 *     anything past it in the row cascade RIGHT.
 *  - `"right"` → source lands just past dropSlot's right edge; the slot
 *     at that cell (if any) cascades RIGHT.
 *  - `"up"` → source lands at dropSlot's topmost cell; dropSlot
 *     cascades DOWN.
 *  - `"down"` → source lands just past dropSlot's bottom edge; the slot
 *     at that cell (if any) cascades DOWN.
 *
 * The source's own cells (if `sourceKey` is non-null and the source is
 * already in the grid) are treated as vacant during planning — this
 * is what lets the canonical `A, B, C → C, A, B` rearrange succeed:
 * C's old cell absorbs B's shift.
 *
 * Assumes the source lands as 1×1; multi-span sources from other grids
 * (or the same grid) land 1×1 here and the author can resize.
 *
 * @param {{
 *   slots: Array<Object>,
 *   sourceKey: string|null,
 *   dropSlotKey: string,
 *   direction: "left"|"right"|"up"|"down",
 *   gridDims: {columns: number, rows: number}
 * }} args
 * @returns {{
 *   moves: Array<{slotKey: string, column: string, row: string}>,
 *   sourceLanding: {column: string, row: string}
 * }|null}
 */
export function computeShiftPlan({
  slots,
  sourceKey,
  dropSlotKey,
  dropCell,
  direction,
  gridDims,
}) {
  const maxCol = gridDims.columns;
  const maxRow = gridDims.rows;

  // Build rect index, dropping the source's rect (treated as vacant).
  const rects = new Map();
  for (const slot of slots ?? []) {
    const key = entryKey(slot);
    if (!key || key === sourceKey) {
      continue;
    }
    const placement = parsePlacement(slot.containerArgs);
    if (placement.column.start == null || placement.row.start == null) {
      continue;
    }
    rects.set(key, {
      colStart: placement.column.start,
      colEnd: placement.column.end ?? placement.column.start + 1,
      rowStart: placement.row.start,
      rowEnd: placement.row.end ?? placement.row.start + 1,
    });
  }

  // Drop rect: either an existing slot's rect, or a virtual 1×1 at a
  // cell coordinate (for empty-cell edge drops). The shift algorithm
  // doesn't care which — it only needs a rectangle to anchor the
  // landing position and cascade direction.
  let dropRect;
  if (dropSlotKey) {
    dropRect = rects.get(dropSlotKey);
    if (!dropRect) {
      return null;
    }
  } else if (dropCell) {
    dropRect = {
      colStart: dropCell.column,
      colEnd: dropCell.column + 1,
      rowStart: dropCell.row,
      rowEnd: dropCell.row + 1,
    };
  } else {
    return null;
  }

  // Landing position and cascade axis.
  let landingCol, landingRow, axis;
  if (direction === "left") {
    landingCol = dropRect.colStart;
    landingRow = dropRect.rowStart;
    axis = "column";
  } else if (direction === "right") {
    landingCol = dropRect.colEnd;
    landingRow = dropRect.rowStart;
    axis = "column";
  } else if (direction === "up") {
    landingCol = dropRect.colStart;
    landingRow = dropRect.rowStart;
    axis = "row";
  } else {
    // "down"
    landingCol = dropRect.colStart;
    landingRow = dropRect.rowEnd;
    axis = "row";
  }

  // Clamp out-of-bounds landings to the trailing edge of the grid.
  // Without this, dropping on the right edge of the LAST column
  // (e.g. "after C" in a 3-col grid → landingCol = 4) would return
  // null immediately. Clamping to maxCol means the source displaces
  // the trailing slot; the bidirectional cascade below figures out
  // where the displaced slot goes.
  if (landingCol > maxCol) {
    landingCol = maxCol;
  }
  if (landingRow > maxRow) {
    landingRow = maxRow;
  }
  if (landingCol < 1 || landingRow < 1) {
    return null;
  }

  // Try a forward cascade (slots shift +1 on the axis). When the
  // forward cascade walks off the grid (e.g. source is to the LEFT
  // of the landing, so there's no room to push further right), fall
  // back to a backward cascade (slots shift -1, using the space the
  // source vacated). This lets `A, B, C → B, C, A` succeed via the
  // same drop gesture as the symmetric `A, B, C → C, A, B`.
  const forward = _attemptCascade({
    rects,
    landingCol,
    landingRow,
    axis,
    cascadeForward: true,
    maxCol,
    maxRow,
  });
  if (forward) {
    return forward;
  }
  return _attemptCascade({
    rects,
    landingCol,
    landingRow,
    axis,
    cascadeForward: false,
    maxCol,
    maxRow,
  });
}

/**
 * One cascade attempt — either forward (shift +1, source's vacated
 * cell is to the RIGHT/BELOW the landing) or backward (shift -1,
 * source's vacated cell is to the LEFT/ABOVE). Returns the move plan
 * if everything fits without overflowing the grid; `null` otherwise.
 */
function _attemptCascade({
  rects,
  landingCol,
  landingRow,
  axis,
  cascadeForward,
  maxCol,
  maxRow,
}) {
  // The first slot to displace is whatever overlaps the source's
  // intended landing rect. If that cell is empty, scan along the
  // cascade direction to find the nearest neighbour — that's the
  // "ripple shift" semantic for empty-cell edge drops.
  const firstShifted = _findFirstSlotInDirection(
    rects,
    landingCol,
    landingRow,
    axis,
    maxCol,
    maxRow,
    cascadeForward
  );

  const moves = [];
  const shifted = new Set();
  let cursor = firstShifted;

  while (cursor) {
    if (shifted.has(cursor)) {
      return null;
    }
    shifted.add(cursor);
    const rect = rects.get(cursor);
    if (!rect) {
      return null;
    }
    const newRect = _shiftRect(rect, axis, cascadeForward);
    if (cascadeForward) {
      if (newRect.colEnd > maxCol + 1 || newRect.rowEnd > maxRow + 1) {
        return null;
      }
    } else {
      if (newRect.colStart < 1 || newRect.rowStart < 1) {
        return null;
      }
    }
    moves.push({ slotKey: cursor, newRect });
    let next = null;
    for (const [key, otherRect] of rects) {
      if (key === cursor || shifted.has(key)) {
        continue;
      }
      if (_rectsOverlap(newRect, otherRect)) {
        next = key;
        break;
      }
    }
    cursor = next;
  }

  // Validate: replay moves and the source's landing onto a fresh map.
  const finalRects = new Map(rects);
  for (const move of moves) {
    finalRects.set(move.slotKey, move.newRect);
  }
  const sourceRect = {
    colStart: landingCol,
    colEnd: landingCol + 1,
    rowStart: landingRow,
    rowEnd: landingRow + 1,
  };
  for (const [, rect] of finalRects) {
    if (_rectsOverlap(sourceRect, rect)) {
      return null;
    }
  }
  const keys = [...finalRects.keys()];
  for (let i = 0; i < keys.length; i++) {
    for (let j = i + 1; j < keys.length; j++) {
      if (_rectsOverlap(finalRects.get(keys[i]), finalRects.get(keys[j]))) {
        return null;
      }
    }
  }

  return {
    moves: moves.map((m) => ({
      slotKey: m.slotKey,
      column: _rectToTrackString(m.newRect.colStart, m.newRect.colEnd),
      row: _rectToTrackString(m.newRect.rowStart, m.newRect.rowEnd),
    })),
    sourceLanding: {
      column: `${landingCol}`,
      row: `${landingRow}`,
    },
  };
}

function _findSlotAt(rects, col, row) {
  for (const [key, rect] of rects) {
    if (
      col >= rect.colStart &&
      col < rect.colEnd &&
      row >= rect.rowStart &&
      row < rect.rowEnd
    ) {
      return key;
    }
  }
  return null;
}

/**
 * Scans from `(startCol, startRow)` in the given axis (forward
 * direction only — column = right, row = down) and returns the first
 * slot key whose rect covers that cell. Returns `null` if no slot is
 * found before the grid edge. Used to find the head of the cascade
 * chain regardless of whether the drop target itself is a slot or
 * an empty cell.
 */
function _findFirstSlotInDirection(
  rects,
  startCol,
  startRow,
  axis,
  maxCol,
  maxRow,
  cascadeForward = true
) {
  if (axis === "column") {
    if (cascadeForward) {
      for (let c = startCol; c <= maxCol; c++) {
        const slot = _findSlotAt(rects, c, startRow);
        if (slot) {
          return slot;
        }
      }
    } else {
      for (let c = startCol; c >= 1; c--) {
        const slot = _findSlotAt(rects, c, startRow);
        if (slot) {
          return slot;
        }
      }
    }
  } else {
    if (cascadeForward) {
      for (let r = startRow; r <= maxRow; r++) {
        const slot = _findSlotAt(rects, startCol, r);
        if (slot) {
          return slot;
        }
      }
    } else {
      for (let r = startRow; r >= 1; r--) {
        const slot = _findSlotAt(rects, startCol, r);
        if (slot) {
          return slot;
        }
      }
    }
  }
  return null;
}

function _shiftRect(rect, axis, cascadeForward = true) {
  const delta = cascadeForward ? 1 : -1;
  if (axis === "column") {
    return {
      colStart: rect.colStart + delta,
      colEnd: rect.colEnd + delta,
      rowStart: rect.rowStart,
      rowEnd: rect.rowEnd,
    };
  }
  return {
    colStart: rect.colStart,
    colEnd: rect.colEnd,
    rowStart: rect.rowStart + delta,
    rowEnd: rect.rowEnd + delta,
  };
}

function _rectsOverlap(a, b) {
  return (
    a.colStart < b.colEnd &&
    b.colStart < a.colEnd &&
    a.rowStart < b.rowEnd &&
    b.rowStart < a.rowEnd
  );
}

function _rectToTrackString(start, end) {
  return end === start + 1 ? `${start}` : `${start} / ${end}`;
}

function fillRect(occupied, placement, columns, rows) {
  const colStart = clamp(placement.column.start, 1, columns);
  const colEnd = clamp(placement.column.end, colStart + 1, columns + 1);
  const rowStart = clamp(placement.row.start, 1, rows);
  const rowEnd = clamp(placement.row.end, rowStart + 1, rows + 1);
  for (let r = rowStart; r < rowEnd; r++) {
    for (let c = colStart; c < colEnd; c++) {
      occupied.add(cellKey(r, c));
    }
  }
}

function nextFreeCell(occupied, columns, rows, start) {
  let cursor = start;
  while (cursor && cursor.row <= rows) {
    if (!occupied.has(cellKey(cursor.row, cursor.column))) {
      return cursor;
    }
    cursor = advance(cursor, columns);
  }
  return null;
}

function advance(cursor, columns) {
  if (cursor.column >= columns) {
    return { row: cursor.row + 1, column: 1 };
  }
  return { row: cursor.row, column: cursor.column + 1 };
}

function cellKey(row, column) {
  return `${row},${column}`;
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}
