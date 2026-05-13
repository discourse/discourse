// @ts-check
import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";

const VALID_MODES = ["stack", "row", "grid", "free-grid"];
const VALID_COUNTS = [2, 3, 4];
const VALID_ALIGNS = ["start", "center", "end", "stretch"];

/**
 * Container layout block.
 *
 * Modes:
 *  - `stack` — flex column, children stack vertically (default).
 *  - `row` — flex row, children flow horizontally.
 *  - `grid` — auto-flowing CSS Grid with `count` equal columns;
 *     children flow in document order, no per-child placement.
 *  - `free-grid` — CSS Grid with explicit `columns` / `rows`
 *     dimensions. Children are `ve:slot` blocks that carry their
 *     own `column` / `row` placement; the layout block itself sets
 *     up the grid template and renders slots as direct children.
 *
 * `free-grid` is the mode the visual editor's grid surface targets
 * (Phase 7s). The other modes remain for quick simple stacking /
 * rowing without per-child positioning.
 */
@block("ve:layout", {
  container: true,
  displayName: "Layout",
  icon: "table-cells-large",
  category: "Layout",
  description:
    "A flexible container — stack (column), row, auto-grid, or free-grid with per-cell placement.",
  args: {
    mode: {
      type: "string",
      default: "stack",
      enum: VALID_MODES,
      ui: { label: "Mode" },
    },
    count: {
      type: "number",
      default: 2,
      integer: true,
      enum: VALID_COUNTS,
      ui: { label: "Columns (auto-grid only)" },
    },
    gap: {
      type: "number",
      default: 1,
      min: 0,
      max: 4,
      ui: { label: "Gap (rem)" },
    },
    align: {
      type: "string",
      default: "stretch",
      enum: VALID_ALIGNS,
      ui: { label: "Alignment" },
    },
    // Free-grid args. Ignored by stack / row / auto-grid modes.
    columns: {
      type: "number",
      default: 6,
      integer: true,
      min: 1,
      max: 24,
      ui: { label: "Columns (free-grid)" },
    },
    rows: {
      type: "number",
      default: 2,
      integer: true,
      min: 1,
      max: 24,
      ui: { label: "Rows (free-grid)" },
    },
    columnTemplate: {
      type: "string",
      default: "",
      ui: {
        label: "Column template",
        placeholder: "e.g. 1fr 2fr 1fr (overrides Columns)",
      },
    },
    rowTemplate: {
      type: "string",
      default: "",
      ui: {
        label: "Row template",
        placeholder: "e.g. auto 1fr (overrides Rows)",
      },
    },
    // Default uses `minmax(60px, auto)` rather than bare `auto` so empty
    // rows stay visible at a usable height — the editor's grid overlay
    // sizes itself to the layout's resolved track sizes, and a 0px row
    // (which `auto` resolves to when the cell has no content yet)
    // would collapse the overlay and leave nothing to drop into.
    rowHeight: {
      type: "string",
      default: "minmax(60px, auto)",
      ui: {
        label: "Row height",
        placeholder: "auto, 120px, minmax(80px, auto)",
      },
    },
  },
  previewArgs: { mode: "stack", gap: 1, align: "stretch" },
})
export default class VELayout extends Component {
  /**
   * Container layout style driven by the `mode` arg.
   *
   * For stack / row, we use flexbox. For auto-grid (`mode: "grid"`),
   * we use CSS Grid with `repeat(count, 1fr)`. For free-grid, we
   * resolve the column / row templates and let each child slot
   * position itself via its own `grid-column` / `grid-row` styles.
   *
   * Transitions are applied so changing `columns` / `gap` / templates
   * from the inspector animates smoothly — matches the
   * cssgridgenerator-style feel where adding a column glides instead
   * of popping.
   */
  get containerStyle() {
    const mode = this.args.mode ?? "stack";
    const gap = this.args.gap ?? 1;
    const align = this.args.align ?? "stretch";

    if (mode === "grid") {
      const count = this.args.count ?? 2;
      return trustHTML(
        `display: grid; grid-template-columns: repeat(${count}, 1fr); ` +
          `gap: ${gap}rem; align-items: ${align}; ` +
          `transition: grid-template-columns 180ms ease, ` +
          `grid-template-rows 180ms ease, gap 180ms ease;`
      );
    }

    if (mode === "free-grid") {
      const columns = this.args.columns ?? 6;
      const rows = this.args.rows ?? 2;
      const columnTemplate = (this.args.columnTemplate ?? "").trim();
      const rowTemplate = (this.args.rowTemplate ?? "").trim();
      const rowHeight =
        (this.args.rowHeight ?? "minmax(60px, auto)").trim() ||
        "minmax(60px, auto)";

      const gridTemplateColumns =
        columnTemplate.length > 0 ? columnTemplate : `repeat(${columns}, 1fr)`;
      const gridTemplateRows =
        rowTemplate.length > 0 ? rowTemplate : `repeat(${rows}, ${rowHeight})`;

      return trustHTML(
        `display: grid; grid-template-columns: ${gridTemplateColumns}; ` +
          `grid-template-rows: ${gridTemplateRows}; ` +
          `gap: ${gap}rem; align-items: ${align}; ` +
          `transition: grid-template-columns 180ms ease, ` +
          `grid-template-rows 180ms ease, gap 180ms ease;`
      );
    }

    const direction = mode === "row" ? "row" : "column";
    return trustHTML(
      `display: flex; flex-direction: ${direction}; gap: ${gap}rem; ` +
        `align-items: ${align};`
    );
  }

  get className() {
    return `ve-layout ve-layout--${this.args.mode ?? "stack"}`;
  }

  <template>
    <div class={{this.className}} style={{this.containerStyle}}>
      {{#each @children key="key" as |child|}}
        <child.Component />
      {{/each}}
    </div>
  </template>
}
