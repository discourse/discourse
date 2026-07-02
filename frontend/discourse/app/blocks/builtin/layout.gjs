// @ts-check
import Component from "@glimmer/component";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";
import {
  DEFAULT_GRID_COLUMNS,
  DEFAULT_GRID_ROWS,
  gridDimensions,
  LAYOUT_MERGED_CELL_BLOCK,
  normalizeFractions,
  parsePlacement,
} from "discourse/lib/blocks";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

const VALID_MODES = ["stack", "row", "grid", "tiles"];
const VALID_ALIGNS = ["start", "center", "end", "stretch"];
const VALID_ALIGN_SELF = ["auto", "start", "center", "end", "stretch"];
const VALID_JUSTIFY_CONTENT = [
  "start",
  "center",
  "end",
  "space-between",
  "space-around",
  "space-evenly",
];
const VALID_JUSTIFY_ITEMS = ["start", "center", "end", "stretch"];
const VALID_ALIGN_CONTENT = [
  "start",
  "center",
  "end",
  "space-between",
  "space-around",
  "stretch",
];

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
 *  - `tiles` — CSS Grid that fits as many equal columns as the container
 *     width allows (`repeat(auto-fit, minmax(minItemWidth, 1fr))`).
 *     Children carry no placement and reflow automatically as the width
 *     changes, so this mode is for uniform sets (e.g. a card grid) rather
 *     than a deliberately-placed layout.
 */
@block("layout", {
  thumbnail: () => import("discourse/blocks/thumbnails/layout"),
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
          center: "wf-align-center",
          end: "down-long",
          stretch: "arrows-up-down",
        },
      },
    },
    // Main-axis distribution. Applies to flex modes (stack / row) and to grid
    // (inline-axis track distribution). `start` matches the current default in
    // every mode, so it's a no-op for existing layouts.
    justifyContent: {
      type: "string",
      default: "start",
      enum: VALID_JUSTIFY_CONTENT,
      ui: { label: i18n("blocks.builtin.layout.justify_content") },
    },
    // Reverses the visual order of children. Implemented by reversing the
    // rendered children array (not CSS `*-reverse`), so DOM / tab / screen-reader
    // order stays in step with the visual order. Flex modes only.
    reverse: {
      type: "boolean",
      default: false,
      ui: { control: "toggle", label: i18n("blocks.builtin.layout.reverse") },
    },
    // Row mode only: whether children wrap onto new lines. Default `wrap` matches
    // the previously-hardcoded row behaviour. The responsive collapse forces wrap
    // below its breakpoint regardless (see the stylesheet).
    wrap: {
      type: "string",
      default: "wrap",
      enum: ["wrap", "nowrap"],
      ui: {
        control: "segmented",
        label: i18n("blocks.builtin.layout.wrap"),
        conditional: { arg: "mode", equals: "row" },
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
    // Grid only: default inline-axis alignment of each cell within its track
    // (the block-axis complement is the shared `align` arg). `stretch` matches
    // the current grid default.
    justifyItems: {
      type: "string",
      default: "stretch",
      enum: VALID_JUSTIFY_ITEMS,
      ui: {
        control: "segmented",
        label: i18n("blocks.builtin.layout.justify_items"),
        conditional: { arg: "mode", equals: "grid" },
      },
    },
    // Grid only: block-axis distribution of the tracks when the grid is shorter
    // than its container. `stretch` matches the current grid default.
    alignContent: {
      type: "string",
      default: "stretch",
      enum: VALID_ALIGN_CONTENT,
      ui: {
        label: i18n("blocks.builtin.layout.align_content"),
        conditional: { arg: "mode", equals: "grid" },
      },
    },
    // Grid only: when true, the grid backfills earlier gaps with later items
    // (`grid-auto-flow: row dense`).
    dense: {
      type: "boolean",
      default: false,
      ui: {
        control: "toggle",
        label: i18n("blocks.builtin.layout.dense"),
        conditional: { arg: "mode", equals: "grid" },
      },
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
    // Tiles mode only: the minimum width each child gets before the row
    // wraps. The grid fits as many equal `minmax(minItemWidth, 1fr)` columns
    // as the container width allows, so children reflow without any explicit
    // placement.
    minItemWidth: {
      type: "string",
      default: "16rem",
      ui: {
        label: i18n("blocks.builtin.layout.min_item_width"),
        placeholder: i18n("blocks.builtin.layout.min_item_width_placeholder"),
        conditional: { arg: "mode", equals: "tiles" },
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
              start: "wf-align-start-horizontal",
              center: "wf-align-center-horizontal",
              end: "wf-align-end-horizontal",
              stretch: "wf-stretch-horizontal",
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
              start: "wf-align-start-vertical",
              center: "wf-align-center-vertical",
              end: "wf-align-end-vertical",
              stretch: "wf-stretch-vertical",
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
              start: "wf-align-start-vertical",
              center: "wf-align-center-vertical",
              end: "wf-align-end-vertical",
              stretch: "wf-stretch-vertical",
            },
          },
        },
        flexGrow: {
          type: "number",
          default: 0,
          min: 0,
          ui: {
            control: "stepper",
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
              start: "wf-align-start-horizontal",
              center: "wf-align-center-horizontal",
              end: "wf-align-end-horizontal",
              stretch: "wf-stretch-horizontal",
            },
          },
        },
        flexGrow: {
          type: "number",
          default: 0,
          min: 0,
          ui: {
            control: "stepper",
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
  @service blocks;

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
    const justifyContent = this.args.justifyContent ?? "start";

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
        this.renderedChildren
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

      const autoFlow = this.args.dense ? "row dense" : "row";
      return trustHTML(
        `--d-block-layout-cols: ${gridTemplateColumns}; ` +
          `--d-block-layout-rows: ${gridTemplateRows}; ` +
          `--d-block-layout-gap: ${gap}rem; ` +
          `--d-block-layout-align: ${align}; ` +
          `--d-block-layout-justify-content: ${justifyContent}; ` +
          `--d-block-layout-justify-items: ${this.args.justifyItems ?? "stretch"}; ` +
          `--d-block-layout-align-content: ${this.args.alignContent ?? "stretch"}; ` +
          `--d-block-layout-auto-flow: ${autoFlow};`
      );
    }

    if (mode === "tiles") {
      // Auto-fit reflow: the stylesheet's `.d-block-layout--tiles` rule reads
      // this min-item-width into `repeat(auto-fit, minmax(<width>, 1fr))`, so
      // the browser decides the column count from the available width. No
      // per-child placement is involved.
      const minItemWidth =
        (this.args.minItemWidth ?? "16rem").trim() || "16rem";
      return trustHTML(
        `--d-block-layout-min-item-width: ${minItemWidth}; ` +
          `--d-block-layout-gap: ${gap}rem; --d-block-layout-align: ${align};`
      );
    }

    // Stack / row (flex). Both carry gap / align / justify-content; only row
    // exposes wrap (a column's flex-wrap is niche, so stack stays the implicit
    // `nowrap` by not emitting the var).
    let style =
      `--d-block-layout-gap: ${gap}rem; --d-block-layout-align: ${align}; ` +
      `--d-block-layout-justify-content: ${justifyContent};`;
    if (mode === "row") {
      style += ` --d-block-layout-wrap: ${this.args.wrap ?? "wrap"};`;
    }
    return trustHTML(style);
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
  /**
   * The children this layout actually renders.
   *
   * In grid mode on the LIVE (non-editor) path, a merged cell
   * (`layout-merged-cell`) holds no content — but its `containerArgs.grid`
   * still claims a track, so a row or column that exists ONLY to hold merged
   * cells would show an empty band (the row's `minmax(80px, auto)` floor) to a
   * visitor. Dropping merged cells from the rendered set there makes such a
   * track collapse (it's neither counted by `gridDimensions` nor wrapped in a
   * cell). In the editor (`blocks.showGhosts`) they ARE kept, so the author
   * sees the held-open space they're shaping. A track shared with content is
   * unaffected — the content keeps it. Stack / row modes never have merged
   * cells, so the filter is grid-only.
   *
   * @returns {Array<Object>}
   */
  get renderedChildren() {
    const children = this.args.children ?? [];
    if (this.resolvedMode === "grid" && !this.blocks.showGhosts) {
      return children.filter(
        (child) => child.blockName !== LAYOUT_MERGED_CELL_BLOCK
      );
    }
    // Flex reverse is done here by reordering the DOM (a reversed copy — the
    // source array is owned upstream), NOT via CSS `flex-direction: *-reverse`,
    // so tab and screen-reader order follow the visual order. Grid early-returns
    // above, so its placement sort and merged-cell filter are untouched.
    if (
      (this.resolvedMode === "stack" || this.resolvedMode === "row") &&
      this.args.reverse
    ) {
      return [...children].reverse();
    }
    return children;
  }

  get sortedChildren() {
    const children = this.renderedChildren;
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
      {{#if (eq this.resolvedMode "grid")}}
        {{#each this.sortedChildren key="key" as |child|}}
          <div
            class="d-block-layout__cell"
            style={{this.cellStyle child.containerArgs}}
          >
            <child.Component />
          </div>
        {{/each}}
      {{else if (eq this.resolvedMode "tiles")}}
        {{#each this.sortedChildren key="key" as |child|}}
          <child.Component />
        {{/each}}
      {{else}}
        {{! Stack / row: an inner flex wrapper holds the children. The flex
          declarations live on this wrapper (not the outer element) so the
          responsive-collapse container query can force flex-wrap on it — a
          descendant of the query context, which the container element itself
          can't be. }}
        <div class="d-block-layout__flex">
          {{#each this.sortedChildren key="key" as |child|}}
            <child.Component />
          {{/each}}
        </div>
      {{/if}}
    </div>
  </template>
}

/**
 * An empty cell within a grid `layout` — a region spanning one or more base
 * grid cells that is intentionally left empty (a hero rail, a sidebar gap). It
 * carries `containerArgs.grid` like any positioned child, so the layout's
 * renderer wraps it in a `.d-block-layout__cell` that claims its grid area
 * while rendering no content. A *filled* region is an ordinary child with a
 * span; this block exists only to hold an EMPTY region's footprint as a
 * first-class entry, so the region survives save / load and stays editable.
 *
 * Only meaningful as a child of a grid-mode `layout`. On the live page it
 * renders nothing; a layout collapses merged-cell-only rows for visitors (see
 * `Layout.renderedChildren`). Themes that want to target it can match
 * `[data-block-name="layout-merged-cell"]` (there is no `.block-<name>` class).
 */
@block(LAYOUT_MERGED_CELL_BLOCK, {
  displayName: "Merged cell",
  category: "Layout",
  icon: "border-none",
  paletteHidden: true,
})
export class LayoutMergedCell extends Component {
  <template>
    {{! Claims its grid area; renders nothing on the live page. }}
  </template>
}
