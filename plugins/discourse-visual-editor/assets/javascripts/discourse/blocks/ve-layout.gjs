// @ts-check
import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";

const VALID_MODES = ["stack", "row", "grid"];
const VALID_ALIGNS = ["start", "center", "end", "stretch"];

/**
 * Container layout block.
 *
 * Modes:
 *  - `stack` — flex column, children stack vertically (default).
 *  - `row` — flex row, children flow horizontally.
 *  - `grid` — CSS Grid with explicit `columns` / `rows` dimensions.
 *     Children are `ve:slot` blocks that carry their own `column` /
 *     `row` placement; the layout block itself sets up the grid
 *     template and renders slots as direct children. This is the
 *     mode the visual editor's per-cell editor targets.
 *
 * Legacy: an earlier mode `"free-grid"` is coerced to `"grid"` at
 * read time so existing saved layouts keep rendering. The previous
 * auto-flow `"grid"` (with `count` columns) has been removed —
 * stack/row covers single-axis layouts; the new `grid` covers
 * everything else.
 */
@block("ve:layout", {
  container: true,
  displayName: "Layout",
  icon: "table-cells-large",
  category: "Layout",
  description:
    "A flexible container — stack (column), row, or grid with per-cell placement.",
  args: {
    mode: {
      type: "string",
      default: "stack",
      enum: VALID_MODES,
      ui: { label: "Mode" },
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
    // Grid args. Ignored by stack / row modes.
    columns: {
      type: "number",
      default: 6,
      integer: true,
      min: 1,
      max: 24,
      ui: { label: "Columns" },
    },
    rows: {
      type: "number",
      default: 2,
      integer: true,
      min: 1,
      max: 24,
      ui: { label: "Rows" },
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
    // `minmax(0, 1fr)` so rows split the container's height equally
    // regardless of content. `1fr` on its own keeps an auto minimum
    // (tracks can't shrink below content), which made rows inflate
    // unevenly when one held a tall heading and another was empty.
    // Pair with the container's `min-height` floor (set in
    // `containerStyle`) so the equal distribution has space to work
    // when the grid is empty. Authors can override to "auto", "120px",
    // etc. for content-sized rows.
    rowHeight: {
      type: "string",
      default: "minmax(0, 1fr)",
      ui: {
        label: "Row height",
        placeholder: "minmax(0, 1fr), auto, 120px, minmax(80px, auto)",
      },
    },
  },
  previewArgs: { mode: "stack", gap: 1, align: "stretch" },
})
export default class VELayout extends Component {
  /**
   * Resolved layout mode with legacy values normalised. `"free-grid"`
   * (the pre-rename name) maps to `"grid"`; anything else outside the
   * supported set falls back to `"stack"`.
   */
  get resolvedMode() {
    const raw = this.args.mode ?? "stack";
    if (raw === "free-grid") {
      return "grid";
    }
    return VALID_MODES.includes(raw) ? raw : "stack";
  }

  /**
   * Container layout style driven by the `mode` arg.
   *
   * For stack / row, we use flexbox. For grid, we resolve the column
   * / row templates and let each child slot position itself via its
   * own `grid-column` / `grid-row` styles.
   *
   * Transitions are applied so changing `columns` / `gap` / templates
   * from the inspector animates smoothly — matches the
   * cssgridgenerator-style feel where adding a column glides instead
   * of popping.
   */
  get containerStyle() {
    const mode = this.resolvedMode;
    const gap = this.args.gap ?? 1;
    const align = this.args.align ?? "stretch";

    if (mode === "grid") {
      const columns = this.args.columns ?? 6;
      const rows = this.args.rows ?? 2;
      const columnTemplate = (this.args.columnTemplate ?? "").trim();
      const rowTemplate = (this.args.rowTemplate ?? "").trim();
      let rowHeight =
        (this.args.rowHeight ?? "minmax(0, 1fr)").trim() || "minmax(0, 1fr)";
      // Migrate legacy defaults to the equal-rows model. `1fr` (the
      // previous default) has an auto minimum so rows can't shrink
      // below their content — a tall heading inflates its row above
      // any empty rows. `minmax(0, 1fr)` lets every row shrink to 0
      // and then expand equally into the container's min-height, so
      // rows END UP truly the same size.
      if (
        rowHeight === "minmax(60px, auto)" ||
        rowHeight === "1fr" ||
        rowHeight === "minmax(60px,auto)"
      ) {
        rowHeight = "minmax(0, 1fr)";
      }

      const gridTemplateColumns =
        columnTemplate.length > 0 ? columnTemplate : `repeat(${columns}, 1fr)`;
      const gridTemplateRows =
        rowTemplate.length > 0 ? rowTemplate : `repeat(${rows}, ${rowHeight})`;

      // For flexible rows, the container's `min-height` is what gives
      // `minmax(0, 1fr)` something to distribute — without it the rows
      // would all resolve to 0. 80px per row is enough for typical
      // heading content (~24px text + padding) without producing visible
      // overflow.
      const useFlexRows =
        rowTemplate.length === 0 && rowHeight === "minmax(0, 1fr)";
      const minHeight = useFlexRows ? `min-height: ${rows * 80}px; ` : "";

      // `position: relative` anchors the editor's drop-preview overlay
      // (rendered inside the grid by `GridOverlay` and positioned with
      // absolute pixel coordinates for line-shape variants).
      return trustHTML(
        `display: grid; grid-template-columns: ${gridTemplateColumns}; ` +
          `grid-template-rows: ${gridTemplateRows}; ` +
          `gap: ${gap}rem; align-items: ${align}; ` +
          `position: relative; ` +
          minHeight +
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
    return `ve-layout ve-layout--${this.resolvedMode}`;
  }

  <template>
    <div class={{this.className}} style={{this.containerStyle}}>
      {{#each @children key="key" as |child|}}
        <child.Component />
      {{/each}}
    </div>
  </template>
}
