// @ts-check
import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";

const VALID_COUNTS = [2, 3, 4];

@block("ve:columns", {
  container: true,
  displayName: "Columns",
  icon: "table-columns",
  category: "Layout",
  description:
    "A CSS Grid container. Drop blocks inside to populate the columns.",
  args: {
    count: {
      type: "number",
      default: 2,
      integer: true,
      enum: VALID_COUNTS,
      ui: { label: "Columns" },
    },
    gap: {
      type: "number",
      default: 1,
      min: 0,
      max: 4,
      ui: { label: "Gap (rem)" },
    },
  },
  previewArgs: { count: 2, gap: 1 },
})
export default class VEColumns extends Component {
  get gridStyle() {
    const count = this.args.count ?? 2;
    const gap = this.args.gap ?? 1;
    return trustHTML(
      `grid-template-columns: repeat(${count}, 1fr); gap: ${gap}rem;`
    );
  }

  <template>
    <div class="ve-columns" style={{this.gridStyle}}>
      {{#each @children key="key" as |child|}}
        <child.Component />
      {{/each}}
    </div>
  </template>
}
