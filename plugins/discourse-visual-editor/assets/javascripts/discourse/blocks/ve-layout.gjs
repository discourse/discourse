// @ts-check
import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

const VALID_MODES = ["stack", "row", "grid"];
const VALID_ALIGNS = ["start", "center", "end", "stretch"];
const VALID_ALIGN_SELF = ["auto", "start", "center", "end", "stretch"];

/**
 * Container layout block.
 *
 * Modes:
 *  - `stack` — flex column, children stack vertically (default).
 *  - `row` — flex row, children flow horizontally.
 *  - `grid` — CSS Grid with explicit `columns` / `rows` dimensions.
 *     Each direct child carries its own placement under
 *     `containerArgs.grid` (`column` / `row` / `align` / `justify`);
 *     the layout's template hands each child a precomputed `@style` so
 *     core's `WrappedBlockLayout` puts those CSS Grid declarations on
 *     the child's outer wrapper — the direct DOM child of this layout's
 *     container `<div>`.
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
    // `minmax(80px, auto)` so rows have a sensible floor (an empty
    // cell renders at 80px so the grid stays readable) but grow to
    // their tallest content when the user puts taller blocks in.
    // Equal-rows behaviour (`minmax(0, 1fr)`) is still available via
    // explicit override.
    rowHeight: {
      type: "string",
      default: "minmax(80px, auto)",
      ui: {
        label: "Row height",
        placeholder: "minmax(80px, auto), minmax(0, 1fr), auto, 120px",
      },
    },
  },
  previewArgs: { mode: "stack", gap: 1, align: "stretch" },
  // One namespace per mode. Direct children carry mode-specific placement
  // hints under `containerArgs.<mode>` — e.g. a grid child sets
  // `containerArgs.grid = {column, row, align, justify}` so CSS Grid can
  // position it. Per-namespace `ui.conditional` keeps the inspector showing
  // only the section relevant to the parent's current `mode`.
  childArgs: {
    grid: {
      type: "object",
      default: {
        column: "auto",
        row: "auto",
        align: "stretch",
        justify: "stretch",
      },
      properties: {
        column: {
          type: "string",
          default: "auto",
          ui: {
            label: i18n("visual_editor.inspector.layout.placement.grid_column"),
          },
        },
        row: {
          type: "string",
          default: "auto",
          ui: {
            label: i18n("visual_editor.inspector.layout.placement.grid_row"),
          },
        },
        align: {
          type: "string",
          default: "stretch",
          enum: VALID_ALIGNS,
          ui: {
            label: i18n("visual_editor.inspector.layout.placement.grid_align"),
          },
        },
        justify: {
          type: "string",
          default: "stretch",
          enum: VALID_ALIGNS,
          ui: {
            label: i18n(
              "visual_editor.inspector.layout.placement.grid_justify"
            ),
          },
        },
      },
      ui: {
        label: i18n("visual_editor.inspector.layout.placement.grid_section"),
        conditional: { arg: "mode", equals: "grid" },
      },
    },
    stack: {
      type: "object",
      default: { alignSelf: "auto", flexGrow: 0, order: 0 },
      properties: {
        alignSelf: {
          type: "string",
          default: "auto",
          enum: VALID_ALIGN_SELF,
          ui: {
            label: i18n("visual_editor.inspector.layout.placement.align_self"),
          },
        },
        flexGrow: {
          type: "number",
          default: 0,
          min: 0,
          ui: {
            label: i18n("visual_editor.inspector.layout.placement.flex_grow"),
          },
        },
        order: {
          type: "number",
          default: 0,
          integer: true,
          ui: {
            label: i18n("visual_editor.inspector.layout.placement.order"),
          },
        },
      },
      ui: {
        label: i18n("visual_editor.inspector.layout.placement.stack_section"),
        conditional: { arg: "mode", equals: "stack" },
      },
    },
    row: {
      type: "object",
      default: { alignSelf: "auto", flexGrow: 0, order: 0 },
      properties: {
        alignSelf: {
          type: "string",
          default: "auto",
          enum: VALID_ALIGN_SELF,
          ui: {
            label: i18n("visual_editor.inspector.layout.placement.align_self"),
          },
        },
        flexGrow: {
          type: "number",
          default: 0,
          min: 0,
          ui: {
            label: i18n("visual_editor.inspector.layout.placement.flex_grow"),
          },
        },
        order: {
          type: "number",
          default: 0,
          integer: true,
          ui: {
            label: i18n("visual_editor.inspector.layout.placement.order"),
          },
        },
      },
      ui: {
        label: i18n("visual_editor.inspector.layout.placement.row_section"),
        conditional: { arg: "mode", equals: "row" },
      },
    },
  },
})
export default class VELayout extends Component {
  /**
   * Inline style for the `.ve-layout__cell` wrapper this layout renders
   * around each grid-mode child. The cell wrapper IS the grid item, so
   * it carries CSS Grid placement (`grid-column` / `grid-row`) and acts
   * as a single-cell sub-grid (`display: grid` + `place-items`) that
   * positions its content (the rendered block on the live page) within
   * the cell rectangle.
   *
   * In editor mode the chrome wrapper sits inside the cell wrapper and
   * overrides its `place-items` via SCSS — the chrome always stretches
   * to fill the cell so its outline traces the full cell rectangle.
   * The chrome then re-applies the same `align` / `justify` choice to
   * its own inner `__content` wrapper, which positions the block
   * inside the chrome.
   *
   * @param {Object} [containerArgs]
   * @returns {ReturnType<typeof trustHTML>|null}
   */
  cellStyle = (containerArgs) => {
    if (this.resolvedMode !== "grid") {
      return null;
    }
    const grid = containerArgs?.grid ?? {};
    const column = grid.column ?? "auto";
    const row = grid.row ?? "auto";
    const align = grid.align ?? "stretch";
    const justify = grid.justify ?? "stretch";
    return trustHTML(
      `grid-column: ${column}; grid-row: ${row}; ` +
        `display: grid; place-items: ${align} ${justify}; ` +
        `min-width: 0; min-height: 0;`
    );
  };

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
      const rowHeight =
        (this.args.rowHeight ?? "minmax(80px, auto)").trim() ||
        "minmax(80px, auto)";

      const gridTemplateColumns =
        columnTemplate.length > 0 ? columnTemplate : `repeat(${columns}, 1fr)`;
      const gridTemplateRows =
        rowTemplate.length > 0 ? rowTemplate : `repeat(${rows}, ${rowHeight})`;

      // `padding: var(--visual-editor-container-margin)` compensates
      // for the chrome's own outer margin, which adds visible
      // breathing room OUTSIDE the chrome but has no equivalent
      // INSIDE. Without it the gap between the layout's border and
      // its cells reads 2px short of the gap between the layout
      // chrome and its parent's border — the "unaccounted border"
      // the cells lack. Using the container-margin variable keeps
      // the two sides in sync if the spacing token ever changes.
      //
      // `position: relative` anchors the editor's drop-preview overlay
      // (rendered inside the grid by `GridOverlay` and positioned with
      // absolute pixel coordinates for line-shape variants).
      return trustHTML(
        `display: grid; grid-template-columns: ${gridTemplateColumns}; ` +
          `grid-template-rows: ${gridTemplateRows}; ` +
          `gap: ${gap}rem; align-items: ${align}; ` +
          `padding: var(--visual-editor-container-margin); ` +
          `position: relative; ` +
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
        {{#if (eq this.resolvedMode "grid")}}
          <div
            class="ve-layout__cell"
            style={{this.cellStyle child.containerArgs}}
          >
            <child.Component />
          </div>
        {{else}}
          <child.Component />
        {{/if}}
      {{/each}}
    </div>
  </template>
}
