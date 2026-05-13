// @ts-check

/**
 * Preset grid templates surfaced by the inspector's layout form
 * (Phase 7s.8). Each template sets the layout's args — column count,
 * row count, column / row templates, gap — and nothing else. Cells
 * stay empty so the author fills them in by clicking the `+` cells
 * in the grid overlay. Applying a template never auto-inserts
 * placeholder content.
 *
 * Each template carries:
 *
 *  - `id` — stable identifier used as the chip value.
 *  - `i18nKey` — locale path under
 *    `visual_editor.inspector.layout.templates.*`.
 *  - `args` — the `ve:layout` args to write (mode is always
 *    `grid` here).
 */
export const GRID_TEMPLATES = Object.freeze([
  {
    id: "twelve-col",
    i18nKey: "twelve_col",
    args: {
      mode: "grid",
      columns: 12,
      rows: 1,
      gap: 1,
      align: "stretch",
      columnTemplate: "",
      rowTemplate: "",
    },
  },
  {
    id: "hero-plus-three",
    i18nKey: "hero_plus_three",
    args: {
      mode: "grid",
      columns: 3,
      rows: 2,
      gap: 1,
      align: "stretch",
      columnTemplate: "",
      rowTemplate: "",
    },
    // The literal "hero + 3" shape: one wide block spanning the full
    // top row, three separate blocks across the bottom. Used by the
    // inspector's template thumbnail so authors can recognise the
    // layout at a glance — applied data still just sets the grid frame
    // (3×2 canvas) without auto-creating slots.
    previewShape: [
      { column: "1 / 4", row: "1" },
      { column: "1", row: "2" },
      { column: "2", row: "2" },
      { column: "3", row: "2" },
    ],
  },
  {
    id: "sidebar-main",
    i18nKey: "sidebar_main",
    args: {
      mode: "grid",
      columns: 2,
      rows: 1,
      gap: 1,
      align: "stretch",
      columnTemplate: "1fr 3fr",
      rowTemplate: "",
    },
  },
  {
    id: "three-tile",
    i18nKey: "three_tile",
    args: {
      mode: "grid",
      columns: 3,
      rows: 1,
      gap: 1,
      align: "stretch",
      columnTemplate: "",
      rowTemplate: "",
    },
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
