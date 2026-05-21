// @ts-check
import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import { parsePlacement } from "../lib/grid-math";

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
      ui: { control: "radio-group", label: "Mode" },
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
      ui: {
        control: "radio-group",
        label: "Alignment",
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
        group: "Advanced",
        label: "Column template",
        placeholder: "e.g. 1fr 2fr 1fr (overrides Columns)",
      },
    },
    rowTemplate: {
      type: "string",
      default: "",
      ui: {
        group: "Advanced",
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
        group: "Advanced",
        label: "Row height",
        placeholder: "minmax(80px, auto), minmax(0, 1fr), auto, 120px",
      },
    },
    // Per-layout opt-out / customization of the responsive collapse.
    // The `@container` rules in `visual-editor.scss` key off the
    // `ve-layout--collapse-<value>` modifier class emitted by
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
        label: i18n("visual_editor.inspector.layout.auto_collapse_label"),
      },
    },
  },
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
            control: "radio-group",
            label: i18n("visual_editor.inspector.layout.placement.grid_align"),
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
            label: i18n(
              "visual_editor.inspector.layout.placement.grid_justify"
            ),
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
        label: i18n("visual_editor.inspector.layout.placement.grid_section"),
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
            label: i18n("visual_editor.inspector.layout.placement.align_self"),
            // Stack mode is a flex column, so `align-self` acts on the
            // horizontal (cross) axis: left / center / right / stretch.
            optionIcons: {
              start: "ve-align-left",
              center: "ve-align-center-horizontal",
              end: "ve-align-right",
              stretch: "ve-arrows-horizontal",
            },
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
      },
      ui: {
        label: i18n("visual_editor.inspector.layout.placement.stack_section"),
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
            label: i18n("visual_editor.inspector.layout.placement.align_self"),
            // Row mode is a flex row, so `align-self` acts on the
            // vertical (cross) axis: top / center / bottom / stretch.
            optionIcons: {
              start: "ve-align-top",
              center: "ve-align-center-vertical",
              end: "ve-align-bottom",
              stretch: "ve-arrows-vertical",
            },
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
   * around each grid-mode child. The cell wrapper IS the grid item.
   *
   * Emits ONLY CSS custom properties (`--ve-cell-column`, etc.) — the
   * actual `grid-column`, `grid-row`, `display: grid`, `place-items`,
   * and `min-*` declarations live in the stylesheet on
   * `.ve-layout--grid > .ve-layout__cell`. Same rationale as
   * `containerStyle`: a parent `@container ve-layout` rule can then
   * override the cell's `grid-column` at narrow widths (e.g. force
   * full-width when the grid collapses to one column).
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
    // `order` is read by CSS Grid auto-placement only — when the
    // layout collapses to one column under `@container`, every cell
    // gets `grid-row: auto` and the browser flows them in order order.
    // Setting order here keeps slot chromes interleaved correctly with
    // the editor's empty-cell placeholders (which set the same key)
    // in the stacked view. Harmless in the expanded grid: explicit
    // `grid-column` / `grid-row` placements take priority.
    const placement = parsePlacement(containerArgs);
    const orderRow = placement.row.start ?? 1;
    const orderCol = placement.column.start ?? 1;
    const order = (orderRow - 1) * 1000 + (orderCol - 1);
    return trustHTML(
      `--ve-cell-column: ${column}; --ve-cell-row: ${row}; ` +
        `--ve-cell-align: ${align}; --ve-cell-justify: ${justify}; ` +
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
   * Emits ONLY CSS custom properties (`--ve-layout-cols`, etc.) — the
   * actual layout declarations (`display: grid`, `grid-template-*`,
   * `flex-direction`, `transition`, etc.) live in the stylesheet on
   * `.ve-layout--{mode}` rules. This separation lets a parent
   * `@container ve-layout` rule override the actual `grid-template-
   * columns` at narrow widths; an inline `style` declaration would
   * otherwise always win over the query rule.
   *
   * Transitions (declared in the stylesheet) animate smoothly when
   * the author changes `columns` / `gap` / templates from the
   * inspector — adding a column glides instead of popping.
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

      return trustHTML(
        `--ve-layout-cols: ${gridTemplateColumns}; ` +
          `--ve-layout-rows: ${gridTemplateRows}; ` +
          `--ve-layout-gap: ${gap}rem; ` +
          `--ve-layout-align: ${align};`
      );
    }

    return trustHTML(
      `--ve-layout-gap: ${gap}rem; --ve-layout-align: ${align};`
    );
  }

  get className() {
    // Mode + collapse modifier. The collapse class drives which
    // `@container` rule in `visual-editor.scss` applies to this
    // layout (40rem for `--collapse-default`, 20rem for
    // `--collapse-compact`, no rule for `--collapse-never`).
    return (
      `ve-layout ve-layout--${this.resolvedMode} ` +
      `ve-layout--collapse-${this.args.autoCollapse ?? "default"}`
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
   *    column at narrow widths (`@container ve-layout (max-width:
   *    40rem)` in visual-editor.scss), every cell gets
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
