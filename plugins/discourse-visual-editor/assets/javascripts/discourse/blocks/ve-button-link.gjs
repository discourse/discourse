// @ts-check
import Component from "@glimmer/component";
import { block } from "discourse/blocks";
import DButton from "discourse/ui-kit/d-button";

const VALID_VARIANTS = ["primary", "default", "danger"];

@block("ve:button-link", {
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
  previewArgs: { label: "Learn more", href: "/", variant: "default" },
})
export default class VEButtonLink extends Component {
  get btnClass() {
    return `ve-button-link btn-${this.args.variant ?? "default"}`;
  }

  <template>
    <DButton
      class={{this.btnClass}}
      @href={{@href}}
      @translatedLabel={{@label}}
      @icon={{@icon}}
    />
  </template>
}
