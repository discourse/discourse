// @ts-check
import { LAYOUT_MERGED_CELL_BLOCK, parsePlacement } from "discourse/blocks";
import {
  computeOccupation,
  unoccupiedCells,
} from "discourse/plugins/discourse-wireframe/discourse/lib/grid-math";

/**
 * Preset grid layouts surfaced by the inspector's layout form.
 *
 * Each template optionally declares its shape as a
 * `grid-template-areas`-style string: each line is a row, each
 * whitespace-separated token names a cell, a dot (`.`) marks an
 * explicitly-empty cell, and identical names across adjacent cells
 * coalesce into one rectangle. Example:
 *
 *   hero hero hero
 *   a    b    c
 *
 * `parseGridAreas` turns the string into `{columns, rows, slots}`
 * where each slot is a `{column, row}` rect in CSS Grid line syntax.
 * `resolveTemplateLayout` merges the parsed frame with the template's
 * static `args` and returns those rects; the service reflows the
 * layout's existing content into them in reading order on apply, and
 * any still-empty spanning rects become merged-cell entries.
 *
 * A template without an `areas` string would set the grid dimensions
 * only, and the service would reflow content into the grid's individual
 * cells; every preset here declares `areas`.
 *
 * `args` carries the non-positional config (mode, gap, alignment).
 * Columns / rows for templates with areas come from the parsed
 * shape, not `args`.
 */

// Only presets with a distinctive spanning shape earn a place here. A
// uniform `columns × rows` grid of single cells IS free mode, so those
// (a plain N-column row, a stack of full-width sections) are reached via
// the Free control + the column / row fields, not a template. This keeps
// the catalog aligned with `matchGridTemplate`, which skips shapes with
// no span — so every template here is matchable and gets highlighted.
export const GRID_TEMPLATES = Object.freeze([
  {
    id: "hero-plus-three",
    i18nKey: "hero_plus_three",
    areas: `
      hero hero hero
      a    b    c
    `,
    args: { mode: "grid", gap: 1, align: "stretch" },
  },
  {
    id: "sidebar-main",
    i18nKey: "sidebar_main",
    areas: `
      sidebar main main main
    `,
    args: { mode: "grid", gap: 1, align: "stretch" },
  },
  {
    id: "right-sidebar",
    i18nKey: "right_sidebar",
    areas: `
      main main main sidebar
    `,
    args: { mode: "grid", gap: 1, align: "stretch" },
  },
  {
    id: "magazine",
    i18nKey: "magazine",
    areas: `
      lead lead aside
      lead lead aside
    `,
    args: { mode: "grid", gap: 1, align: "stretch" },
  },
  {
    id: "hero-plus-grid",
    i18nKey: "hero_plus_grid",
    areas: `
      hero hero
      a    b
      c    d
    `,
    args: { mode: "grid", gap: 1, align: "stretch" },
  },
]);

/**
 * Looks up a template by id. Returns `null` for unknown ids so
 * callers (the inspector's preset chips) can fail soft.
 *
 * @param {string} id
 * @returns {Object|null}
 */
export function findGridTemplate(id) {
  return GRID_TEMPLATES.find((t) => t.id === id) ?? null;
}

/**
 * Parses a `grid-template-areas`-style string into the grid frame
 * (column / row count) plus a list of slot rects. See the module
 * comment for the shape it expects. Returns `null` for empty /
 * unparseable input so callers can skip auto-placement.
 *
 * Names that span discontiguous cells in the source (`hero . hero`)
 * still emit a single rect covering the bounding box — we don't
 * reject non-rectangular shapes here because the templates in this
 * file are author-controlled. Runtime author input goes through the
 * validator instead.
 *
 * @param {string} areasString
 * @returns {{columns: number, rows: number, slots: Array<{column: string, row: string}>}|null}
 */
export function parseGridAreas(areasString) {
  if (typeof areasString !== "string") {
    return null;
  }
  const lines = areasString
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean);
  if (lines.length === 0) {
    return null;
  }
  const grid = lines.map((line) => line.split(/\s+/));
  const rows = grid.length;
  const columns = Math.max(...grid.map((row) => row.length));

  /** @type {Map<string, {minR: number, maxR: number, minC: number, maxC: number}>} */
  const rects = new Map();
  for (let r = 0; r < grid.length; r++) {
    for (let c = 0; c < grid[r].length; c++) {
      const name = grid[r][c];
      if (!name || name === ".") {
        continue;
      }
      if (!rects.has(name)) {
        rects.set(name, { minR: r, maxR: r, minC: c, maxC: c });
      } else {
        const rect = rects.get(name);
        rect.minR = Math.min(rect.minR, r);
        rect.maxR = Math.max(rect.maxR, r);
        rect.minC = Math.min(rect.minC, c);
        rect.maxC = Math.max(rect.maxC, c);
      }
    }
  }

  // CSS grid lines are 1-indexed, end-line is exclusive. Single-cell
  // rects collapse to a bare line number so the resulting strings
  // round-trip identically with `formatTrack` (`"1"` vs `"1 / 2"`).
  const slots = [];
  for (const rect of rects.values()) {
    const colStart = rect.minC + 1;
    const colEnd = rect.maxC + 2;
    const rowStart = rect.minR + 1;
    const rowEnd = rect.maxR + 2;
    slots.push({
      column:
        colEnd - colStart === 1 ? `${colStart}` : `${colStart} / ${colEnd}`,
      row: rowEnd - rowStart === 1 ? `${rowStart}` : `${rowStart} / ${rowEnd}`,
    });
  }
  return { columns, rows, slots };
}

/**
 * Resolves a template's full layout payload — the frame args (mode,
 * columns, rows, gap, align, ...) plus the rect entries the service
 * reflows content into on apply. A template without `areas` returns
 * `slotEntries: []`; the service then reflows content into the grid's
 * individual cells instead.
 *
 * @param {Object} template
 * @returns {{args: Object, slotEntries: Array<Object>}}
 */
export function resolveTemplateLayout(template) {
  const baseArgs = { ...(template.args ?? {}) };
  const parsed = template.areas ? parseGridAreas(template.areas) : null;
  if (!parsed) {
    return { args: baseArgs, slotEntries: [] };
  }
  const args = {
    ...baseArgs,
    columns: parsed.columns,
    rows: parsed.rows,
    columnTemplate: baseArgs.columnTemplate ?? "",
    rowTemplate: baseArgs.rowTemplate ?? "",
  };
  const slotEntries = parsed.slots.map((slot) => ({
    block: LAYOUT_MERGED_CELL_BLOCK,
    containerArgs: {
      grid: {
        column: slot.column,
        row: slot.row,
        align: "stretch",
        justify: "stretch",
      },
    },
  }));
  return { args, slotEntries };
}

/**
 * Canonical key for a `{column, row}` rect — `colStart/colEnd/rowStart/rowEnd`
 * with end lines resolved, so `"1"` and `"1 / 2"` (both single cells) and
 * equivalent spans compare equal regardless of how they were written.
 *
 * @param {{column?: string, row?: string}} rect
 * @returns {string}
 */
function rectKey(rect) {
  const placement = parsePlacement({ grid: rect ?? {} });
  const cs = placement.column.start ?? 1;
  const ce = placement.column.end ?? cs + 1;
  const rs = placement.row.start ?? 1;
  const re = placement.row.end ?? rs + 1;
  return `${cs}/${ce}/${rs}/${re}`;
}

/**
 * The set of rect keys a grid currently occupies: every child's rect
 * (content and empty merged cells alike) plus the single cells no child
 * covers (the overlay's derived empties). Together these describe the
 * grid's shape regardless of how its cells are filled.
 *
 * @param {Array<Object>} children
 * @param {number} columns
 * @param {number} rows
 * @returns {Set<string>}
 */
function gridRectKeys(children, columns, rows) {
  const keys = new Set();
  for (const child of children ?? []) {
    keys.add(rectKey(child.containerArgs?.grid));
  }
  const occupied = computeOccupation(children ?? [], columns, rows);
  for (const cell of unoccupiedCells(occupied, columns, rows)) {
    keys.add(rectKey({ column: `${cell.column}`, row: `${cell.row}` }));
  }
  return keys;
}

/**
 * Finds the preset template whose shape matches a grid's current shape,
 * or `null` when none does (which the inspector reads as "Free"). The
 * match is on geometry — same dimensions and same set of rects — not on
 * how the cells are filled, so a half-built "Hero + 3" still matches.
 *
 * Frame-only / uniform presets are skipped: a plain `columns × rows`
 * grid of single cells IS free mode, so only presets with a distinctive
 * spanning shape claim a grid. This is why a uniform 3×1 grid reads as
 * "Free" rather than "3 tiles" — they are geometrically identical.
 *
 * @param {Array<Object>} children - The grid layout's children.
 * @param {number} columns
 * @param {number} rows
 * @returns {Object|null} The matching template, or `null` for Free.
 */
export function matchGridTemplate(children, columns, rows) {
  const current = gridRectKeys(children, columns, rows);
  for (const template of GRID_TEMPLATES) {
    const { args, slotEntries } = resolveTemplateLayout(template);
    if (slotEntries.length === 0) {
      continue;
    }
    if ((args.columns ?? 0) !== columns || (args.rows ?? 0) !== rows) {
      continue;
    }
    const templateKeys = new Set(
      slotEntries.map((entry) => rectKey(entry.containerArgs.grid))
    );
    if (
      templateKeys.size === current.size &&
      [...templateKeys].every((key) => current.has(key))
    ) {
      return template;
    }
  }
  return null;
}
