// @ts-check
import Component from "@glimmer/component";
import { block } from "discourse/blocks";
import { ICON_NAME_PATTERN } from "discourse/lib/blocks";
import RichTextRenderer from "discourse/lib/blocks/-internals/rich-text-renderer";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const VALID_TONES = ["info", "success", "warning", "danger"];

@block("callout", {
  thumbnail: () => import("discourse/blocks/thumbnails/callout"),
  displayName: "Callout",
  icon: "circle-info",
  category: "Content",
  description: "A bordered notice card with an icon.",
  args: {
    tone: {
      type: "string",
      default: "info",
      enum: VALID_TONES,
      ui: {
        control: "radio-group",
        label: i18n("blocks.builtin.callout.tone"),
      },
    },
    icon: {
      type: "string",
      default: "circle-info",
      pattern: ICON_NAME_PATTERN,
      ui: { control: "icon", label: i18n("blocks.builtin.callout.icon") },
    },
    body: {
      type: "richInline",
      required: true,
      ui: {
        control: "rich-inline",
        schema: "paragraph",
        label: i18n("blocks.builtin.callout.body"),
      },
    },
  },
})
export default class Callout extends Component {
  /**
   * Composes the BEM class list, appending a `--<tone>` modifier so the
   * stylesheet can paint each tone with the matching colour palette.
   *
   * @returns {string}
   */
  get calloutClass() {
    return `d-block-callout d-block-callout--${this.args.tone ?? "info"}`;
  }

  <template>
    <div class={{this.calloutClass}}>
      <span class="d-block-callout__icon">
        {{#if @icon}}
          <span class="d-block-inline-icon" data-block-arg="icon">
            {{dIcon @icon}}
          </span>
        {{/if}}
      </span>
      <RichTextRenderer
        @arg="body"
        @schema="paragraph"
        @value={{@body}}
        @placeholder={{i18n "blocks.builtin.placeholders.callout_body"}}
        as |R|
      >
        <span class="d-block-callout__body">
          <R.Content />
        </span>
      </RichTextRenderer>
    </div>
  </template>
}
