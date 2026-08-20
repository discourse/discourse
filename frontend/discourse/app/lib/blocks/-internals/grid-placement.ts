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
 */

/** A single grid-line span: 1-indexed start / end line numbers, or `null`. */
export interface Track {
  start: number | null;
  end: number | null;
}

/** A cell's placement across both grid axes. */
export interface SlotPlacement {
  column: Track;
  row: Track;
}

/**
 * Default grid dimensions for a `layout` block in grid mode. The single source
 * of truth for "how big is an unsized grid" — used by the block's arg schema
 * defaults and by every consumer that falls back when `args.columns` /
 * `args.rows` are absent, so the fallbacks can't drift apart.
 */
export const DEFAULT_GRID_COLUMNS = 3;
export const DEFAULT_GRID_ROWS = 2;

/**
 * Block name of the core "merged cell" — an empty positioned region in a grid
 * `layout`. The single source for the name so the block definition, the
 * live-path collapse in the layout renderer, and any consumer that detects an
 * empty cell all reference one value and can't drift apart.
 */
export const LAYOUT_MERGED_CELL_BLOCK = "layout-merged-cell";

/**
 * Parses a `column` / `row` arg pair into start / end line numbers.
 * Returns `{start: null, end: null}` tracks for auto / span / unknown
 * placements.
 *
 * @param args - The grid namespace object carrying `column` / `row` strings.
 * @returns The parsed placement.
 */
export function parseSlotPlacement(
  args?: { column?: unknown; row?: unknown } | null
): SlotPlacement {
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
 * @param containerArgs - A child entry's container args.
 * @returns The parsed placement.
 */
export function parsePlacement(
  containerArgs?: Record<string, unknown> | null
): SlotPlacement {
  const grid = containerArgs?.grid as
    | { column?: unknown; row?: unknown }
    | undefined;
  return parseSlotPlacement(grid);
}

/**
 * The effective dimensions of a grid layout — the larger of its declared
 * `columns` / `rows` and what its children actually occupy. A grid must
 * always contain its content: a child placed at `column: "2 / 4"` needs
 * three columns regardless of the declared count, so the grid reports
 * three. This is the single source of truth for "how big is this grid",
 * so the rendered track count, any consumer that reports the grid's size,
 * and the stored args can never drift apart (a bare `args.columns ?? default`
 * read in one place and a different default in another is exactly the mismatch
 * this prevents).
 *
 * @param declared - The declared `columns` / `rows`. Callers pass the value
 *   already defaulted (e.g. `args.columns ?? 3`) so an empty grid still reports
 *   its default size.
 * @param children - The grid's child entries; each contributes its placement's
 *   far edge to the extent.
 * @returns The effective column / row counts.
 */
export function gridDimensions(
  declared?: { columns?: number; rows?: number } | null,
  children?: ReadonlyArray<{
    containerArgs?: Record<string, unknown> | null;
  }> | null
): { columns: number; rows: number } {
  let columns = Math.max(1, Math.trunc(declared?.columns ?? NaN) || 1);
  let rows = Math.max(1, Math.trunc(declared?.rows ?? NaN) || 1);
  for (const child of children ?? []) {
    const { column, row } = parsePlacement(child.containerArgs);
    // `parseTrack` always resolves a set start to an end (single cell →
    // `end = start + 1`), so the far edge is `end - 1` columns / rows.
    if (column.end != null) {
      columns = Math.max(columns, column.end - 1);
    }
    if (row.end != null) {
      rows = Math.max(rows, row.end - 1);
    }
  }
  return { columns, rows };
}

/**
 * Coerces a column-fractions array to exactly `count` positive numbers —
 * padding short arrays with `1` (a balanced track) and truncating long
 * ones. This is what makes the fractions model immune to the count drift
 * that an opaque `grid-template-columns` string suffers: however the
 * stored array got out of step with the column count (a column added,
 * a reflow), the rendered track list always has exactly one entry per
 * column. Non-finite / non-positive entries fall back to `1`.
 *
 * @param fractions - The stored column fractions, or undefined/short/overlong;
 *   each missing or invalid entry falls back to `1`.
 * @param count - The grid's effective column count.
 * @returns Exactly `count` positive fraction values.
 */
export function normalizeFractions(
  fractions: readonly number[] | null | undefined,
  count: number
): number[] {
  const out: number[] = [];
  for (let i = 0; i < count; i++) {
    const value = Number(fractions?.[i]);
    out.push(Number.isFinite(value) && value > 0 ? value : 1);
  }
  return out;
}

/**
 * Parses a single CSS Grid line shorthand. Examples:
 *
 *  - `"1 / 4"` → `{start: 1, end: 4}`
 *  - `"2"` → `{start: 2, end: 3}` (single-line span 1)
 *  - `"auto"` / `""` / undefined → `{start: null, end: null}`
 *
 * @param raw - The raw grid-line shorthand value.
 * @returns The parsed track.
 */
export function parseTrack(raw: unknown): Track {
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
