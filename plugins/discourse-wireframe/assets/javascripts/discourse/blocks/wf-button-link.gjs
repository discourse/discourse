// @ts-check
import Component from "@glimmer/component";
import { block } from "discourse/blocks";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import RichTextRenderer from "../components/rich-text-renderer";
import { ICON_NAME_PATTERN, URL_PATTERN } from "../lib/arg-patterns";

const VALID_VARIANTS = ["primary", "default", "danger"];

@block("wf:button-link", {
  displayName: "Button Link",
  icon: "link",
  category: "Navigation",
  description: "A button-styled link.",
  args: {
    label: {
      type: "richInline",
      ui: { control: "rich-inline", label: "Label" },
    },
    href: {
      type: "string",
      required: true,
      pattern: URL_PATTERN,
      ui: { control: "url", label: "Link URL" },
    },
    variant: {
      type: "string",
      default: "default",
      enum: VALID_VARIANTS,
      ui: { control: "radio-group", label: "Style" },
    },
    icon: {
      type: "string",
      pattern: ICON_NAME_PATTERN,
      ui: { control: "icon", label: "Icon" },
    },
  },
  constraints: {
    atLeastOne: ["label", "icon"],
  },
})
export default class WFButtonLink extends Component {
  /**
   * Composes the DButton class list, mixing the wireframe BEM root with
   * the variant-derived core button class so the rendered control picks
   * up DButton's existing primary / default / danger styling.
   *
   * @returns {string}
   */
  get btnClass() {
    return `wf-button-link btn-${this.args.variant ?? "default"}`;
  }

  <template>
    {{! Block-form DButton (instead of `@icon` / `@translatedLabel`) so
        the icon and label each render in their own click-to-edit wrapper
        while still matching DButton's spacing. }}
    <DButton class={{this.btnClass}} @href={{@href}} data-block-arg="href">
      <span
        class="wf-inline-icon {{unless @icon 'wf-inline-icon--empty'}}"
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
        @placeholder={{i18n "wireframe.placeholders.button_link_label"}}
        as |R|
      >
        <span class="d-button-label"><R.Content /></span>
      </RichTextRenderer>
    </DButton>
  </template>
}
