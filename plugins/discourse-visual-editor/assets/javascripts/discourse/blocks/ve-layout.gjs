// @ts-check
import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";
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
            label: i18n(
              "discourse_visual_editor.editor.layout.placement.grid_column"
            ),
          },
        },
        row: {
          type: "string",
          default: "auto",
          ui: {
            label: i18n(
              "discourse_visual_editor.editor.layout.placement.grid_row"
            ),
          },
        },
        align: {
          type: "string",
          default: "stretch",
          enum: VALID_ALIGNS,
          ui: {
            label: i18n(
              "discourse_visual_editor.editor.layout.placement.grid_align"
            ),
          },
        },
        justify: {
          type: "string",
          default: "stretch",
          enum: VALID_ALIGNS,
          ui: {
            label: i18n(
              "discourse_visual_editor.editor.layout.placement.grid_justify"
            ),
          },
        },
      },
      ui: {
        label: i18n(
          "discourse_visual_editor.editor.layout.placement.grid_section"
        ),
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
            label: i18n(
              "discourse_visual_editor.editor.layout.placement.align_self"
            ),
          },
        },
        flexGrow: {
          type: "number",
          default: 0,
          min: 0,
          ui: {
            label: i18n(
              "discourse_visual_editor.editor.layout.placement.flex_grow"
            ),
          },
        },
        order: {
          type: "number",
          default: 0,
          integer: true,
          ui: {
            label: i18n(
              "discourse_visual_editor.editor.layout.placement.order"
            ),
          },
        },
      },
      ui: {
        label: i18n(
          "discourse_visual_editor.editor.layout.placement.stack_section"
        ),
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
            label: i18n(
              "discourse_visual_editor.editor.layout.placement.align_self"
            ),
          },
        },
        flexGrow: {
          type: "number",
          default: 0,
          min: 0,
          ui: {
            label: i18n(
              "discourse_visual_editor.editor.layout.placement.flex_grow"
            ),
          },
        },
        order: {
          type: "number",
          default: 0,
          integer: true,
          ui: {
            label: i18n(
              "discourse_visual_editor.editor.layout.placement.order"
            ),
          },
        },
      },
      ui: {
        label: i18n(
          "discourse_visual_editor.editor.layout.placement.row_section"
        ),
        conditional: { arg: "mode", equals: "row" },
      },
    },
  },
})
export default class VELayout extends Component {
  /**
   * Per-child inline style for the wrapper that core's
   * `WrappedBlockLayout` renders around every block. The wrapper is the
   * direct DOM child of this layout's container `<div>`, which makes it
   * the right element to receive CSS Grid placement (or, in future modes,
   * flexbox per-child overrides). Returns `null` for stack / row modes,
   * which let flexbox auto-place children.
   *
   * @param {Object} [containerArgs] - The child entry's `containerArgs`.
   * @returns {ReturnType<typeof trustHTML>|null}
   */
  childStyle = (containerArgs) => {
    if (this.resolvedMode !== "grid") {
      return null;
    }
    const grid = containerArgs?.grid;
    if (!grid) {
      return null;
    }
    const parts = [];
    if (grid.column != null) {
      parts.push(`grid-column: ${grid.column};`);
    }
    if (grid.row != null) {
      parts.push(`grid-row: ${grid.row};`);
    }
    if (grid.align != null) {
      parts.push(`align-self: ${grid.align};`);
    }
    if (grid.justify != null) {
      parts.push(`justify-self: ${grid.justify};`);
    }
    return parts.length ? trustHTML(parts.join(" ")) : null;
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
        <child.Component @style={{this.childStyle child.containerArgs}} />
      {{/each}}
    </div>
  </template>
}
