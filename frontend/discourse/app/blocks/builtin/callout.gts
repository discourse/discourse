import Component from "@glimmer/component";
import { block } from "discourse/blocks";
import { ICON_NAME_PATTERN } from "discourse/lib/blocks";
import RichTextRenderer from "discourse/lib/blocks/-internals/rich-text-renderer";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const VALID_TONES = ["info", "success", "warning", "danger"];

/**
 * A rich-inline argument value: either a plain string or a rich-text document
 * whose inline runs live under `content`. Passed straight through to the shared
 * rich-text renderer, which is the only consumer that inspects its shape.
 */
type RichInlineValue = string | { content?: unknown[] };

interface CalloutSignature {
  Args: {
    tone?: string;
    icon?: string;
    body?: RichInlineValue;
  };
}

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
export default class Callout extends Component<CalloutSignature> {
  /**
   * Composes the BEM class list, appending a `--<tone>` modifier so the
   * stylesheet can paint each tone with the matching colour palette.
   */
  get calloutClass(): string {
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
