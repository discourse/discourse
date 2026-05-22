// @ts-check
import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";

@block("wf:spacer", {
  displayName: "Spacer",
  icon: "arrows-up-down",
  category: "Layout",
  description: "An empty vertical or horizontal gap.",
  args: {
    size: {
      type: "number",
      default: 1,
      min: 0.25,
      max: 8,
      ui: { label: "Size (rem)" },
    },
  },
})
export default class WFSpacer extends Component {
  get style() {
    const size = this.args.size ?? 1;
    return trustHTML(`height: ${size}rem; width: ${size}rem;`);
  }

  <template>
    <div class="wf-spacer" style={{this.style}}></div>
  </template>
}
