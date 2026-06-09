// @ts-check
import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";
import {
  DEFAULT_GRID_COLUMNS,
  DEFAULT_GRID_ROWS,
  gridDimensions,
  normalizeFractions,
  parsePlacement,
} from "discourse/lib/blocks";
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
@block("layout", {
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
      ui: { control: "radio-group", label: i18n("blocks.builtin.layout.mode") },
    },
    gap: {
      type: "number",
      default: 1,
      min: 0,
      max: 4,
      ui: { label: i18n("blocks.builtin.layout.gap") },
    },
    align: {
      type: "string",
      default: "stretch",
      enum: VALID_ALIGNS,
      ui: {
        control: "radio-group",
        label: i18n("blocks.builtin.layout.align"),
        optionIcons: {
          start: "up-long",
          center: "align-center",
          end: "down-long",
          stretch: "arrows-up-down",
        },
      },
    },
    // Grid args. Ignored by stack / row modes.
    columns: {
      type: "number",
      default: DEFAULT_GRID_COLUMNS,
      integer: true,
      min: 1,
      max: 24,
      ui: { label: i18n("blocks.builtin.layout.columns") },
    },
    rows: {
      type: "number",
      default: DEFAULT_GRID_ROWS,
      integer: true,
      min: 1,
      max: 24,
      ui: { label: i18n("blocks.builtin.layout.rows") },
    },
    columnTemplate: {
      type: "string",
      default: "",
      ui: {
        group: "Advanced",
        label: i18n("blocks.builtin.layout.column_template"),
        placeholder: i18n("blocks.builtin.layout.column_template_placeholder"),
      },
    },
    // Per-column width ratios (e.g. `[1, 2, 1]` → `1fr 2fr 1fr`), set by
    // edit-driven tooling; always normalised to one entry per column at
    // render so it can't desync from the count. `columnTemplate` (the raw
    // string escape hatch) takes precedence when both are set.
    columnFractions: {
      type: "array",
      itemType: "number",
      default: [],
    },
    rowTemplate: {
      type: "string",
      default: "",
      ui: {
        group: "Advanced",
        label: i18n("blocks.builtin.layout.row_template"),
        placeholder: i18n("blocks.builtin.layout.row_template_placeholder"),
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
        group: "Advanced",
        label: i18n("blocks.builtin.layout.row_height"),
        placeholder: i18n("blocks.builtin.layout.row_height_placeholder"),
      },
    },
    // Per-layout opt-out / customization of the responsive collapse.
    // The `@container` rules in the stylesheet key off the
    // `d-block-layout--collapse-<value>` modifier class emitted by
    // `className` below.
    //   - `default`: collapse below 40rem (core's `sm`). Cards,
    //     paragraphs, media — typical content.
    //   - `compact`: collapse below 15rem (~240px). Dense content
    //     (icon rows, small buttons) that stays multi-column at all
    //     typical phone widths; only collapses in genuinely tiny
    //     contexts like watch screens.
    //   - `never`: no `@container` rule applies — author keeps the
    //     full layout at every width. For genuinely-dense content
    //     like a row of icons or small links.
    autoCollapse: {
      type: "string",
      default: "default",
      enum: ["never", "compact", "default"],
      ui: {
        control: "radio-group",
        label: i18n("blocks.builtin.layout.auto_collapse_label"),
      },
    },
  },
  // One namespace per mode. Direct children carry mode-specific placement
  // hints under `containerArgs.<mode>` — e.g. a grid child sets
  // `containerArgs.grid = {column, row, align, justify}` so CSS Grid can
  // position it. Per-namespace `ui.conditional` keeps edit tooling showing
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
            label: i18n("blocks.builtin.layout.placement.grid_column"),
          },
        },
        row: {
          type: "string",
          default: "auto",
          ui: {
            label: i18n("blocks.builtin.layout.placement.grid_row"),
          },
        },
        align: {
          type: "string",
          default: "stretch",
          enum: VALID_ALIGNS,
          ui: {
            control: "radio-group",
            label: i18n("blocks.builtin.layout.placement.grid_align"),
            optionIcons: {
              start: "up-long",
              center: "align-center",
              end: "down-long",
              stretch: "arrows-up-down",
            },
          },
        },
        justify: {
          type: "string",
          default: "stretch",
          enum: VALID_ALIGNS,
          ui: {
            control: "radio-group",
            label: i18n("blocks.builtin.layout.placement.grid_justify"),
            optionIcons: {
              start: "align-left",
              center: "align-center",
              end: "align-right",
              stretch: "arrows-left-right",
            },
          },
        },
      },
      ui: {
        label: i18n("blocks.builtin.layout.placement.grid_section"),
        conditional: { arg: "mode", equals: "grid" },
      },
    },
    stack: {
      type: "object",
      default: { alignSelf: "auto", flexGrow: 0 },
      properties: {
        alignSelf: {
          type: "string",
          default: "auto",
          enum: VALID_ALIGN_SELF,
          ui: {
            control: "radio-group",
            label: i18n("blocks.builtin.layout.placement.align_self"),
            // Stack mode is a flex column, so `align-self` acts on the
            // horizontal (cross) axis: left / center / right / stretch.
            optionIcons: {
              start: "align-left",
              center: "align-center",
              end: "align-right",
              stretch: "arrows-left-right",
            },
          },
        },
        flexGrow: {
          type: "number",
          default: 0,
          min: 0,
          ui: {
            label: i18n("blocks.builtin.layout.placement.flex_grow"),
          },
        },
      },
      ui: {
        label: i18n("blocks.builtin.layout.placement.stack_section"),
        conditional: { arg: "mode", equals: "stack" },
      },
    },
    row: {
      type: "object",
      default: { alignSelf: "auto", flexGrow: 0 },
      properties: {
        alignSelf: {
          type: "string",
          default: "auto",
          enum: VALID_ALIGN_SELF,
          ui: {
            control: "radio-group",
            label: i18n("blocks.builtin.layout.placement.align_self"),
            // Row mode is a flex row, so `align-self` acts on the
            // vertical (cross) axis: top / center / bottom / stretch.
            optionIcons: {
              start: "up-long",
              center: "align-center",
              end: "down-long",
              stretch: "arrows-up-down",
            },
          },
        },
        flexGrow: {
          type: "number",
          default: 0,
          min: 0,
          ui: {
            label: i18n("blocks.builtin.layout.placement.flex_grow"),
          },
        },
      },
      ui: {
        label: i18n("blocks.builtin.layout.placement.row_section"),
        conditional: { arg: "mode", equals: "row" },
      },
    },
  },
})
export default class Layout extends Component {
  /**
   * Inline style for the `.d-block-layout__cell` wrapper this layout
   * renders around each grid-mode child. The cell wrapper IS the grid
   * item.
   *
   * Emits ONLY CSS custom properties (`--d-block-cell-column`, etc.) — the
   * actual `grid-column`, `grid-row`, `display: grid`, `place-items`, and
   * `min-*` declarations live in the stylesheet on
   * `.d-block-layout--grid > .d-block-layout__cell`. Same rationale as
   * `containerStyle`: a parent `@container d-block-layout` rule can then
   * override the cell's `grid-column` at narrow widths (e.g. force
   * full-width when the grid collapses to one column).
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
    // `order` is read by CSS Grid auto-placement only — when the layout
    // collapses to one column under `@container`, every cell gets
    // `grid-row: auto` and the browser flows them in DOM order plus this
    // `order`. Setting it here keeps cells interleaved correctly with any
    // edit-time empty-cell placeholders (which set the same key) in the
    // stacked view. Harmless in the expanded grid: explicit `grid-column`
    // / `grid-row` placements take priority.
    const placement = parsePlacement(containerArgs);
    const orderRow = placement.row.start ?? 1;
    const orderCol = placement.column.start ?? 1;
    const order = (orderRow - 1) * 1000 + (orderCol - 1);
    return trustHTML(
      `--d-block-cell-column: ${column}; --d-block-cell-row: ${row}; ` +
        `--d-block-cell-align: ${align}; --d-block-cell-justify: ${justify}; ` +
        `order: ${order};`
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
   * Emits ONLY CSS custom properties (`--d-block-layout-cols`, etc.) — the
   * actual layout declarations (`display: grid`, `grid-template-*`,
   * `flex-direction`, `transition`, etc.) live in the stylesheet on
   * `.d-block-layout--{mode}` rules. This separation lets a parent
   * `@container d-block-layout` rule override the actual `grid-template-
   * columns` at narrow widths; an inline `style` declaration would
   * otherwise always win over the query rule.
   *
   * Transitions (declared in the stylesheet) animate smoothly when the
   * author changes `columns` / `gap` / templates — adding a column glides
   * instead of popping.
   */
  get containerStyle() {
    const mode = this.resolvedMode;
    const gap = this.args.gap ?? 1;
    const align = this.args.align ?? "stretch";

    if (mode === "grid") {
      // Derive the track count from the declared args AND the children's
      // placements — a child spanning past the declared count would
      // otherwise spill into implicit (auto-sized) tracks, breaking the
      // column widths. This is the same `gridDimensions` consumers read,
      // so the rendered grid and any mirrored size never drift.
      const { columns, rows } = gridDimensions(
        {
          columns: this.args.columns ?? DEFAULT_GRID_COLUMNS,
          rows: this.args.rows ?? DEFAULT_GRID_ROWS,
        },
        this.args.children
      );
      const columnTemplate = (this.args.columnTemplate ?? "").trim();
      const rowTemplate = (this.args.rowTemplate ?? "").trim();
      const rowHeight =
        (this.args.rowHeight ?? "minmax(80px, auto)").trim() ||
        "minmax(80px, auto)";

      // Column track sizing, in precedence order: the raw `columnTemplate`
      // escape hatch, then the edit-managed `columnFractions` (always
      // normalised to one entry per column so it can't desync), then an
      // even `repeat`.
      const fractions = this.args.columnFractions;
      let gridTemplateColumns;
      if (columnTemplate.length > 0) {
        gridTemplateColumns = columnTemplate;
      } else if (Array.isArray(fractions) && fractions.length > 0) {
        gridTemplateColumns = normalizeFractions(fractions, columns)
          .map((f) => `${f}fr`)
          .join(" ");
      } else {
        gridTemplateColumns = `repeat(${columns}, 1fr)`;
      }
      const gridTemplateRows =
        rowTemplate.length > 0 ? rowTemplate : `repeat(${rows}, ${rowHeight})`;

      return trustHTML(
        `--d-block-layout-cols: ${gridTemplateColumns}; ` +
          `--d-block-layout-rows: ${gridTemplateRows}; ` +
          `--d-block-layout-gap: ${gap}rem; ` +
          `--d-block-layout-align: ${align};`
      );
    }

    return trustHTML(
      `--d-block-layout-gap: ${gap}rem; --d-block-layout-align: ${align};`
    );
  }

  /**
   * Composes the layout's BEM class list with mode and collapse
   * modifiers. The collapse modifier drives which `@container` rule in
   * the stylesheet applies (40rem for `--collapse-default`, 20rem for
   * `--collapse-compact`, no rule for `--collapse-never`).
   *
   * @returns {string}
   */
  get className() {
    return (
      `d-block-layout d-block-layout--${this.resolvedMode} ` +
      `d-block-layout--collapse-${this.args.autoCollapse ?? "default"}`
    );
  }

  /**
   * Children reordered to match VISUAL reading order in grid mode.
   *
   * Grid layouts persist children in the order they were inserted /
   * moved by the author — NOT in row-then-column visual order. At
   * desktop width that's fine: the explicit `grid-row` / `grid-column`
   * placement on each cell positions it wherever the author wants,
   * independent of DOM order. But this breaks two things otherwise:
   *
   * 1. **Container-query collapse.** When the layout collapses to one
   *    column at narrow widths (`@container d-block-layout (max-width:
   *    40rem)` in the stylesheet), every cell gets
   *    `grid-column: 1 / -1` and `grid-row: auto`, so CSS Grid
   *    auto-places them in DOM order. Persisted-insert order then
   *    determines the stack, which can put a footer-banner on top
   *    and the heading at the bottom.
   * 2. **Accessibility (WCAG 1.3.2 — meaningful sequence).** Screen
   *    readers and tab-key focus follow DOM order, NOT visual order.
   *    At desktop a sighted user reads heading first; a screen reader
   *    user reads whatever's first in the persisted children array
   *    — often the wrong block. The `order` CSS property would solve
   *    the visual-collapse case but NOT this one; MDN warns against
   *    `order` precisely because of the DOM-vs-visual mismatch.
   *
   * Sorting the RENDERED children (not the persisted ones) by
   * `(rowStart, colStart)` fixes both. The persisted JSON keeps the
   * author's edit history; DOM order matches visual reading order;
   * auto-placement at narrow widths flows correctly; screen readers
   * and tab focus walk the layout in the order a sighted user reads
   * it.
   *
   * Stack / row modes return the persisted order unchanged — their
   * visual order IS their DOM order, no remapping needed.
   *
   * RTL: the sort key is the grid-line index, which is direction-
   * agnostic. CSS Grid flips `column: 1` to the right edge in `dir=
   * rtl`, and RTL reading is right-to-left, so the sorted DOM order
   * still matches visual reading order in both directions without a
   * special branch.
   *
   * @returns {Array<Object>} children in row-major reading order
   */
  get sortedChildren() {
    const children = this.args.children ?? [];
    if (this.resolvedMode !== "grid") {
      return children;
    }
    // Copy the array — sort mutates in place and `this.args.children`
    // is owned by the block-outlet pipeline upstream of this block.
    return [...children].sort((a, b) => {
      const aPos = parsePlacement(a.containerArgs);
      const bPos = parsePlacement(b.containerArgs);
      // `parsePlacement` returns `{column: {start, end}, row: ...}`
      // with `start: null` for "auto" / missing placements; treat
      // those as the first cell (row 1, col 1) so unplaced cells
      // come first in reading order rather than getting an
      // arbitrary sort position from NaN comparisons.
      const aRow = aPos.row.start ?? 1;
      const bRow = bPos.row.start ?? 1;
      if (aRow !== bRow) {
        return aRow - bRow;
      }
      const aCol = aPos.column.start ?? 1;
      const bCol = bPos.column.start ?? 1;
      return aCol - bCol;
    });
  }

  <template>
    <div class={{this.className}} style={{this.containerStyle}}>
      {{! Iterate sorted children, NOT `@children` directly. See the
        `sortedChildren` getter's JSDoc for why: keeps DOM order in
        sync with visual reading order so accessibility tooling and
        narrow-width auto-placement both behave correctly. }}
      {{#each this.sortedChildren key="key" as |child|}}
        {{#if (eq this.resolvedMode "grid")}}
          <div
            class="d-block-layout__cell"
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
