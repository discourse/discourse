// @ts-check
import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";

const VALID_STYLES = ["solid", "dashed", "dotted"];

@block("ve:divider", {
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
  previewArgs: { style: "solid" },
})
export default class VEDivider extends Component {
  get hrStyle() {
    const style = this.args.style ?? "solid";
    const color = this.args.color || "var(--primary-low)";
    return trustHTML(
      `border: 0; border-top: 1px ${style} ${color}; margin: 0.5rem 0;`
    );
  }

  <template><hr class="ve-divider" style={{this.hrStyle}} /></template>
}
