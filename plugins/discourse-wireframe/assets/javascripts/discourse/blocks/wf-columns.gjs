// @ts-check
import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";

const VALID_COUNTS = [2, 3, 4];

// Deprecated as of Phase 7p.7. Use `wf:layout` with `mode: "grid"`
// instead. Kept registered (and `paletteHidden`) so existing saved
// layouts continue to resolve. Will be removed in a later release.
@block("wf:columns", {
  container: true,
  displayName: "Columns (deprecated — use Layout)",
  icon: "table-columns",
  category: "Layout",
  description:
    "Deprecated alias for Layout (mode=grid). Use the Layout block instead.",
  paletteHidden: true,
  args: {
    count: {
      type: "number",
      default: 2,
      integer: true,
      enum: VALID_COUNTS,
      ui: { control: "radio-group", label: "Columns" },
    },
    gap: {
      type: "number",
      default: 1,
      min: 0,
      max: 4,
      ui: { label: "Gap (rem)" },
    },
  },
})
export default class WFColumns extends Component {
  get gridStyle() {
    const count = this.args.count ?? 2;
    const gap = this.args.gap ?? 1;
    return trustHTML(
      `grid-template-columns: repeat(${count}, 1fr); gap: ${gap}rem;`
    );
  }

  <template>
    <div class="wf-columns" style={{this.gridStyle}}>
      {{#each @children key="key" as |child|}}
        <child.Component />
      {{/each}}
    </div>
  </template>
}
