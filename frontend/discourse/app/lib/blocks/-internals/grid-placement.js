// @ts-check
/**
 * Pure helpers that read CSS Grid placement out of a child entry's
 * container args. No DOM access — they operate on plain data, so they're
 * trivially unit-testable and safe for the live render path.
 *
 * The grid is 1-indexed (matching CSS Grid's `grid-column` / `grid-row`
 * line numbering). A cell at column C, row R is `{column: C, row: R}`.
 *
 * Placement strings follow CSS Grid shorthand:
 *  - `"1 / 4"` — start at line 1, end at line 4 (spans 3 columns).
 *  - `"2"` — start at line 2, span 1.
 *  - `"auto"` — let CSS Grid auto-place.
 *
 * The parser is conservative: anything it doesn't recognise becomes
 * `{start: null, end: null}` so consumers fall back to auto-placement
 * rather than corrupting the stored data.
 *
 * @module discourse/lib/blocks/-internals/grid-placement
 */

/**
 * @typedef {{start: number|null, end: number|null}} Track
 * @typedef {{column: Track, row: Track}} SlotPlacement
 */

/**
 * Parses a `column` / `row` arg pair into start / end line numbers.
 * Returns `{start: null, end: null}` tracks for auto / span / unknown
 * placements.
 *
 * @param {Object} [args]
 * @returns {SlotPlacement}
 */
export function parseSlotPlacement(args) {
  return {
    column: parseTrack(args?.column),
    row: parseTrack(args?.row),
  };
}

/**
 * Reads grid placement out of a child entry's `containerArgs`. The grid
 * layout namespaces per-parent-mode placement hints under a top-level key
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
