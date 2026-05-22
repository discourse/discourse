// @ts-check
import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";

const VALID_STYLES = ["solid", "dashed", "dotted"];

@block("wf:divider", {
  displayName: "Divider",
  icon: "minus",
  category: "Layout",
  description: "A horizontal rule.",
  args: {
    style: {
      type: "string",
      default: "solid",
      enum: VALID_STYLES,
      ui: { control: "radio-group", label: "Style" },
    },
    color: {
      type: "string",
      default: "",
      ui: { control: "color", label: "Color" },
    },
  },
})
export default class WFDivider extends Component {
  get hrStyle() {
    const style = this.args.style ?? "solid";
    const color = this.args.color || "var(--primary-low)";
    return trustHTML(
      `border: 0; border-top: 1px ${style} ${color}; margin: 0.5rem 0;`
    );
  }

  <template><hr class="wf-divider" style={{this.hrStyle}} /></template>
}
