// @ts-check
import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { block } from "discourse/blocks";
import dElement from "discourse/ui-kit/helpers/d-element";
import { i18n } from "discourse-i18n";
import IconRenderer from "../components/icon-renderer";
import RichTextRenderer from "../components/rich-text-renderer";

const VALID_LEVELS = [1, 2, 3, 4, 5, 6];
const VALID_ALIGNMENTS = ["left", "center", "right"];

@block("wf:heading", {
  displayName: "Heading",
  icon: "heading",
  category: "Content",
  description: "A configurable section heading.",
  args: {
    text: {
      type: "richInline",
      ui: { control: "rich-inline", label: "Text" },
    },
    icon: {
      type: "string",
      default: "",
      ui: { control: "icon", label: "Icon" },
    },
    level: {
      type: "number",
      default: 2,
      integer: true,
      enum: VALID_LEVELS,
      ui: { control: "radio-group", label: "Level" },
    },
    align: {
      type: "string",
      default: "left",
      enum: VALID_ALIGNMENTS,
      ui: {
        control: "radio-group",
        label: "Alignment",
        optionIcons: {
          left: "align-left",
          center: "align-center",
          right: "align-right",
        },
      },
    },
  },
})
export default class WFHeading extends Component {
  get className() {
    return `wf-heading wf-heading--align-${this.args.align ?? "left"}`;
  }

  /**
   * Curried `<hN>` component picked off `@level`. Falls back to `<h2>`
   * for values outside `VALID_LEVELS` (the block's schema enum already
   * constrains this, but the fallback keeps render safe for hand-authored
   * data that slipped past validation).
   */
  get headingTag() {
    const level = this.args.level;
    return dElement(VALID_LEVELS.includes(level) ? `h${level}` : "h2");
  }

  <template>
    <RichTextRenderer
      @arg="text"
      @schema="heading"
      @value={{@text}}
      @placeholder={{i18n "wireframe.placeholders.heading_text"}}
      as |R|
    >
      <this.headingTag
        class={{concat this.className (if R.isEmpty " wf-heading--empty")}}
      ><IconRenderer @value={{@icon}} @arg="icon" /><R.Content
        /></this.headingTag>
    </RichTextRenderer>
  </template>
}
