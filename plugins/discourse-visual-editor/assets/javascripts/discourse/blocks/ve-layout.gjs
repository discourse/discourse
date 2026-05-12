// @ts-check
import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";

const VALID_MODES = ["stack", "row", "grid"];
const VALID_COUNTS = [2, 3, 4];
const VALID_ALIGNS = ["start", "center", "end", "stretch"];

@block("ve:layout", {
  container: true,
  displayName: "Layout",
  icon: "table-cells-large",
  category: "Layout",
  description:
    "A flexible container — stack (column), row, or grid. Replaces ve:columns.",
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
      ui: { label: "Columns (grid only)" },
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
  },
  previewArgs: { mode: "stack", gap: 1, align: "stretch" },
})
export default class VELayout extends Component {
  /**
   * Container layout style driven by the `mode` arg:
   *  - `stack` (default): flex column, children stack vertically.
   *  - `row`: flex row, children flow horizontally.
   *  - `grid`: CSS grid with `count` columns.
   */
  get containerStyle() {
    const mode = this.args.mode ?? "stack";
    const gap = this.args.gap ?? 1;
    const align = this.args.align ?? "stretch";

    if (mode === "grid") {
      const count = this.args.count ?? 2;
      return trustHTML(
        `display: grid; grid-template-columns: repeat(${count}, 1fr); ` +
          `gap: ${gap}rem; align-items: ${align};`
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
