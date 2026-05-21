// @ts-check
import Component from "@glimmer/component";
import { block } from "discourse/blocks";
import dIcon from "discourse/ui-kit/helpers/d-icon";

const VALID_TONES = ["info", "success", "warning", "danger"];

@block("ve:callout", {
  displayName: "Callout",
  icon: "circle-info",
  category: "Content",
  description: "A bordered notice card with an icon.",
  args: {
    tone: {
      type: "string",
      default: "info",
      enum: VALID_TONES,
      ui: { control: "radio-group", label: "Tone" },
    },
    icon: {
      type: "string",
      default: "circle-info",
      ui: { control: "icon", label: "Icon" },
    },
    body: {
      type: "string",
      default: "Important information for the reader.",
      ui: { control: "textarea", label: "Body" },
    },
  },
  previewArgs: {
    tone: "info",
    icon: "circle-info",
    body: "Important information for the reader.",
  },
})
export default class VECallout extends Component {
  get calloutClass() {
    return `ve-callout ve-callout--${this.args.tone ?? "info"}`;
  }

  <template>
    <div class={{this.calloutClass}}>
      <span class="ve-callout__icon">{{dIcon @icon}}</span>
      <span class="ve-callout__body">{{@body}}</span>
    </div>
  </template>
}
