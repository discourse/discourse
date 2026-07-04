// @ts-check
import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { block } from "discourse/blocks";
import { ICON_NAME_PATTERN } from "discourse/lib/blocks";
/** @type {import("discourse/lib/blocks/-internals/rich-text-renderer.gjs")} */
import RichTextRenderer from "discourse/lib/blocks/-internals/rich-text-renderer";
/** @type {import("discourse/ui-kit/helpers/d-element.gjs")} */
import dElement from "discourse/ui-kit/helpers/d-element";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const VALID_LEVELS = [1, 2, 3, 4, 5, 6];
const VALID_ALIGNMENTS = ["left", "center", "right"];

@block("heading", {
  thumbnail:
    /** @type {() => Promise<typeof import("discourse/blocks/thumbnails/heading.gjs")>} */ (
      () => import("discourse/blocks/thumbnails/heading")
    ),
  displayName: "Heading",
  icon: "heading",
  category: "Content",
  description: "A configurable section heading.",
  args: {
    text: {
      type: "richInline",
      required: true,
      ui: {
        control: "rich-inline",
        schema: "heading",
        label: i18n("blocks.builtin.heading.text"),
      },
    },
    icon: {
      type: "string",
      pattern: ICON_NAME_PATTERN,
      ui: { control: "icon", label: i18n("blocks.builtin.heading.icon") },
    },
    level: {
      type: "number",
      default: 2,
      integer: true,
      enum: VALID_LEVELS,
      ui: {
        control: "radio-group",
        label: i18n("blocks.builtin.heading.level"),
      },
    },
    align: {
      type: "string",
      default: "left",
      enum: VALID_ALIGNMENTS,
      ui: {
        control: "radio-group",
        label: i18n("blocks.builtin.heading.align"),
        optionIcons: {
          left: "wf-align-left",
          center: "wf-align-center",
          right: "wf-align-right",
        },
      },
    },
  },
})
export default class Heading extends Component {
  /**
   * Composes the BEM class list, appending a `--align-<value>` modifier
   * for the chosen text alignment.
   *
   * @returns {string}
   */
  get className() {
    return `d-block-heading d-block-heading--align-${this.args.align ?? "left"}`;
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
      @placeholder={{i18n "blocks.builtin.placeholders.heading_text"}}
      as |R|
    >
      <this.headingTag
        class={{concat this.className (if R.isEmpty " d-block-heading--empty")}}
      >{{#if @icon}}<span
            class="d-block-inline-icon"
            data-block-arg="icon"
          >{{dIcon @icon}}</span>{{/if}}<R.Content /></this.headingTag>
    </RichTextRenderer>
  </template>
}
