// @ts-check
import Component from "@glimmer/component";
import { block } from "discourse/blocks";
import DButton from "discourse/ui-kit/d-button";
import IconRenderer from "../components/icon-renderer";

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
    {{! Block-form invocation so the icon renders through `IconRenderer`
        (with its data-attrs for the click-to-edit popover) instead of
        DButton's built-in `@icon` path. We re-create the
        `.d-button-label` wrapper that DButton would otherwise emit
        when `@translatedLabel` is set, so spacing / styling match. }}
    <DButton class={{this.btnClass}} @href={{@href}} data-block-arg="href">
      <IconRenderer @value={{@icon}} @arg="icon" />
      <span class="d-button-label">{{@label}}</span>
    </DButton>
  </template>
}
