// @ts-check
import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";
import DividerThumbnail from "discourse/components/svg/blocks/divider";
import { HEX_COLOR_PATTERN } from "discourse/lib/blocks";
import { i18n } from "discourse-i18n";

const VALID_STYLES = ["solid", "dashed", "dotted"];

@block("divider", {
  thumbnail: DividerThumbnail,
  displayName: "Divider",
  icon: "minus",
  category: "Layout",
  description: "A horizontal rule.",
  args: {
    style: {
      type: "string",
      default: "solid",
      enum: VALID_STYLES,
      ui: {
        control: "radio-group",
        label: i18n("blocks.builtin.divider.style"),
      },
    },
    color: {
      type: "string",
      pattern: HEX_COLOR_PATTERN,
      ui: { control: "color", label: i18n("blocks.builtin.divider.color") },
    },
  },
})
export default class Divider extends Component {
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

  <template><hr class="d-block-divider" style={{this.hrStyle}} /></template>
}
