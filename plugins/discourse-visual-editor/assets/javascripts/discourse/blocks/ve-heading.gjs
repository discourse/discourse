// @ts-check
import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { block } from "discourse/blocks";
import booleanString from "discourse/helpers/boolean-string";
import dElement from "discourse/ui-kit/helpers/d-element";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import InlineRichTextRenderer from "../components/inline-rich-text-renderer";

const VALID_LEVELS = [1, 2, 3, 4, 5, 6];
const VALID_ALIGNMENTS = ["left", "center", "right"];

@block("ve:heading", {
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
export default class VEHeading extends Component {
  get className() {
    return `ve-heading ve-heading--align-${this.args.align ?? "left"}`;
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
    <InlineRichTextRenderer
      @arg="text"
      @schema="heading"
      @value={{@text}}
      @placeholder={{i18n "visual_editor.placeholders.heading_text"}}
      as |R|
    >
      <this.headingTag
        class={{concat this.className (if R.isEmpty " ve-heading--empty")}}
        aria-hidden={{booleanString R.isEmpty}}
      >
        {{#if @icon}}{{dIcon @icon}}{{/if}}<R.Content />
      </this.headingTag>
    </InlineRichTextRenderer>
  </template>
}
