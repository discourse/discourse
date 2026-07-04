// @ts-check
import Component from "@glimmer/component";
import { block } from "discourse/blocks";
import { ICON_NAME_PATTERN, URL_PATTERN } from "discourse/lib/blocks";
/** @type {import("discourse/lib/blocks/-internals/rich-text-renderer.gjs")} */
import RichTextRenderer from "discourse/lib/blocks/-internals/rich-text-renderer";
/** @type {import("discourse/ui-kit/d-button.gjs")} */
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const VALID_VARIANTS = ["primary", "default", "danger"];

@block("button-link", {
  thumbnail: () => import("discourse/blocks/thumbnails/button-link"),
  displayName: "Button Link",
  icon: "link",
  category: "Navigation",
  description: "A button-styled link.",
  args: {
    label: {
      type: "richInline",
      ui: {
        control: "rich-inline",
        schema: "plain",
        label: i18n("blocks.builtin.button_link.label"),
      },
    },
    href: {
      type: "string",
      required: true,
      pattern: URL_PATTERN,
      ui: { control: "url", label: i18n("blocks.builtin.button_link.href") },
    },
    variant: {
      type: "string",
      default: "default",
      enum: VALID_VARIANTS,
      ui: {
        control: "radio-group",
        label: i18n("blocks.builtin.button_link.variant"),
      },
    },
    icon: {
      type: "string",
      pattern: ICON_NAME_PATTERN,
      ui: { control: "icon", label: i18n("blocks.builtin.button_link.icon") },
    },
  },
  constraints: {
    atLeastOne: ["label", "icon"],
  },
})
export default class ButtonLink extends Component {
  /**
   * Composes the DButton class list, mixing the block BEM root with the
   * variant-derived core button class so the rendered control picks up
   * DButton's existing primary / default / danger styling.
   *
   * @returns {string}
   */
  get btnClass() {
    return `d-block-button-link btn-${this.args.variant ?? "default"}`;
  }

  <template>
    {{! Block-form DButton (instead of `@icon` / `@translatedLabel`) so
        the icon and label each render in their own click-to-edit wrapper
        while still matching DButton's spacing. }}
    <DButton class={{this.btnClass}} @href={{@href}} data-block-arg="href">
      <span
        class="d-block-inline-icon
          {{unless @icon 'd-block-inline-icon--empty'}}"
        data-block-arg="icon"
      >
        {{#if @icon}}
          {{dIcon @icon}}
        {{/if}}
      </span>
      <RichTextRenderer
        @arg="label"
        @schema="plain"
        @value={{@label}}
        @placeholder={{i18n "blocks.builtin.placeholders.button_link_label"}}
        as |R|
      >
        <span class="d-button-label"><R.Content /></span>
      </RichTextRenderer>
    </DButton>
  </template>
}
