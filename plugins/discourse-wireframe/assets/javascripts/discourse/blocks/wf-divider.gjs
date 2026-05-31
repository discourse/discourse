// @ts-check
import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";
import { HEX_COLOR_PATTERN } from "../lib/arg-patterns";

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
      pattern: HEX_COLOR_PATTERN,
      ui: { control: "color", label: "Color" },
    },
  },
})
export default class WFDivider extends Component {
  /**
   * Inline border declarations for the `<hr>`, mixing the chosen line
   * style and colour. Falls back to `--primary-low` when no colour is
   * supplied so the divider matches the surrounding theme by default.
   *
   * @returns {ReturnType<typeof trustHTML>}
   */
  get hrStyle() {
    const style = this.args.style ?? "solid";
    const color = this.args.color || "var(--primary-low)";
    return trustHTML(
      `border: 0; border-top: 1px ${style} ${color}; margin: 0.5rem 0;`
    );
  }

  <template><hr class="wf-divider" style={{this.hrStyle}} /></template>
}
