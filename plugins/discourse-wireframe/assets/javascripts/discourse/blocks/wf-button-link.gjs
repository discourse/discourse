// @ts-check
import Component from "@glimmer/component";
import { block } from "discourse/blocks";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import RichTextRenderer from "../components/rich-text-renderer";

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
      default: "/",
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
      default: "",
      ui: { control: "icon", label: "Icon" },
    },
  },
})
export default class WFButtonLink extends Component {
  get btnClass() {
    return `wf-button-link btn-${this.args.variant ?? "default"}`;
  }

  <template>
    {{! Use block-form DButton (rather than `@icon` / `@translatedLabel`)
        so the icon and label each render inside their own click-to-edit
        wrapper while still matching DButton's spacing. }}
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
