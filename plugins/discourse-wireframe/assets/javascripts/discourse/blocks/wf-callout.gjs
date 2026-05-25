// @ts-check
import Component from "@glimmer/component";
import { block } from "discourse/blocks";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import RichTextRenderer from "../components/rich-text-renderer";

const VALID_TONES = ["info", "success", "warning", "danger"];

@block("wf:callout", {
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
      type: "richInline",
      ui: { control: "rich-inline", label: "Body" },
    },
  },
})
export default class WFCallout extends Component {
  get calloutClass() {
    return `wf-callout wf-callout--${this.args.tone ?? "info"}`;
  }

  <template>
    <div class={{this.calloutClass}}>
      <span class="wf-callout__icon">{{dIcon @icon}}</span>
      <RichTextRenderer
        @arg="body"
        @schema="paragraph"
        @value={{@body}}
        @placeholder={{i18n "wireframe.placeholders.callout_body"}}
        as |R|
      >
        <span class="wf-callout__body">
          <R.Content />
        </span>
      </RichTextRenderer>
    </div>
  </template>
}
