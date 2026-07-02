// @ts-check
import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";
import {
  HEX_COLOR_PATTERN,
  ICON_NAME_PATTERN,
  URL_PATTERN,
} from "discourse/lib/blocks";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const VALID_SIZES = ["sm", "md", "lg", "xl"];

/**
 * A standalone icon, optionally a link. A small building block for feature
 * rows and decorative accents — icons elsewhere are arguments on other blocks,
 * this one stands on its own.
 */
@block("icon", {
  thumbnail: () => import("discourse/blocks/thumbnails/icon"),
  displayName: "Icon",
  icon: "star",
  category: "Content",
  description: "A standalone icon, optionally linked.",
  args: {
    icon: {
      type: "string",
      default: "star",
      pattern: ICON_NAME_PATTERN,
      ui: { control: "icon", label: i18n("blocks.builtin.icon.icon") },
    },
    size: {
      type: "string",
      default: "md",
      enum: VALID_SIZES,
      ui: { control: "radio-group", label: i18n("blocks.builtin.icon.size") },
    },
    color: {
      type: "string",
      pattern: HEX_COLOR_PATTERN,
      ui: { control: "color", label: i18n("blocks.builtin.icon.color") },
    },
    href: {
      type: "string",
      pattern: URL_PATTERN,
      ui: { control: "url", label: i18n("blocks.builtin.icon.href") },
    },
  },
})
export default class Icon extends Component {
  /** @returns {string} */
  get className() {
    const size = VALID_SIZES.includes(this.args.size) ? this.args.size : "md";
    return `d-block-icon d-block-icon--${size}`;
  }

  /** @returns {ReturnType<typeof trustHTML>|null} */
  get colorStyle() {
    return this.args.color
      ? trustHTML(`--d-block-icon-color: ${this.args.color}`)
      : null;
  }

  <template>
    {{#if @href}}
      <a class={{this.className}} href={{@href}} style={{this.colorStyle}}>
        <span class="d-block-inline-icon" data-block-arg="icon">
          {{dIcon @icon}}
        </span>
      </a>
    {{else}}
      <span class={{this.className}} style={{this.colorStyle}}>
        <span class="d-block-inline-icon" data-block-arg="icon">
          {{dIcon @icon}}
        </span>
      </span>
    {{/if}}
  </template>
}
