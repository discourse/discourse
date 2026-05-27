// @ts-check
import Component from "@glimmer/component";
import { block } from "discourse/blocks";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";

const VALID_VARIANTS = ["primary", "default", "danger"];

@block("wf:button-link", {
  displayName: "Button Link",
  icon: "link",
  category: "Navigation",
  description: "A button-styled link.",
  args: {
    label: {
      type: "string",
      default: "Learn more",
      ui: { label: "Label" },
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
    {{! Block-form invocation so the icon glyph carries its own
        `data-block-arg` wrapper (for the click-to-edit popover)
        instead of going through DButton's built-in `@icon` path. We
        re-create the `.d-button-label` wrapper that DButton would
        otherwise emit when `@translatedLabel` is set, so spacing and
        styling match. }}
    <DButton class={{this.btnClass}} @href={{@href}} data-block-arg="href">
      {{#if @icon}}
        <span class="wf-inline-icon" data-block-arg="icon">
          {{dIcon @icon}}
        </span>
      {{/if}}
      <span class="d-button-label">{{@label}}</span>
    </DButton>
  </template>
}
