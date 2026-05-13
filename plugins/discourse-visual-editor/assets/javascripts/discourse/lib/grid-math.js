// @ts-check

/**
 * Pure helpers for the free-grid editor (Phase 7s). All functions
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
 * @param {Array<Object>} slots - Child entries of a free-grid layout
 *   (typically `ve:slot` blocks). Reads `slot.args.column` / `.row`.
 * @param {number} columns
 * @param {number} rows
 * @returns {Set<string>}
 */
export function computeOccupation(slots, columns, rows) {
  const occupied = new Set();
  const autoSlots = [];

  for (const slot of slots ?? []) {
    const placement = parseSlotPlacement(slot.args ?? {});
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
