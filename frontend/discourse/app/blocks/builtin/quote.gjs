// @ts-check
import Component from "@glimmer/component";
import { block } from "discourse/blocks";
import QuoteThumbnail from "discourse/components/svg/blocks/quote";
import RichTextRenderer from "discourse/lib/blocks/-internals/rich-text-renderer";
import DLightDarkImg from "discourse/ui-kit/d-light-dark-img";
import { i18n } from "discourse-i18n";

/**
 * A pull quote / testimonial: a quoted passage with an optional attribution
 * (name), role, and avatar. The text fields are rich-inline, so they're edited
 * in place on the canvas.
 */
@block("quote", {
  thumbnail: QuoteThumbnail,
  displayName: "Quote",
  icon: "quote-left",
  category: "Content",
  description: "A testimonial or pull quote with attribution.",
  args: {
    content: {
      type: "richInline",
      required: true,
      ui: {
        control: "rich-inline",
        schema: "paragraph",
        label: i18n("blocks.builtin.quote.content"),
      },
    },
    attribution: {
      type: "richInline",
      ui: {
        control: "rich-inline",
        schema: "plain",
        label: i18n("blocks.builtin.quote.attribution"),
      },
    },
    role: {
      type: "richInline",
      ui: {
        control: "rich-inline",
        schema: "plain",
        label: i18n("blocks.builtin.quote.role"),
      },
    },
    avatar: {
      type: "image",
      allowDark: true,
      allowResize: false,
      aspectRatio: 1,
      defaultFit: "cover",
      ui: { label: i18n("blocks.builtin.quote.avatar") },
    },
  },
})
export default class Quote extends Component {
  <template>
    <figure class="d-block-quote">
      <blockquote class="d-block-quote__content">
        <RichTextRenderer
          @arg="content"
          @schema="paragraph"
          @value={{@content}}
          @placeholder={{i18n "blocks.builtin.placeholders.quote_content"}}
          as |R|
        >
          <R.Content />
        </RichTextRenderer>
      </blockquote>

      <figcaption class="d-block-quote__cite">
        {{#if @avatar.url}}
          <DLightDarkImg
            class="d-block-quote__avatar"
            @lightImg={{@avatar}}
            @darkImg={{@avatar.dark}}
          />
        {{/if}}
        <span class="d-block-quote__identity">
          <RichTextRenderer
            @arg="attribution"
            @schema="plain"
            @value={{@attribution}}
            @placeholder={{i18n
              "blocks.builtin.placeholders.quote_attribution"
            }}
            as |R|
          >
            <span class="d-block-quote__attribution"><R.Content /></span>
          </RichTextRenderer>
          <RichTextRenderer
            @arg="role"
            @schema="plain"
            @value={{@role}}
            @placeholder={{i18n "blocks.builtin.placeholders.quote_role"}}
            as |R|
          >
            <span class="d-block-quote__role"><R.Content /></span>
          </RichTextRenderer>
        </span>
      </figcaption>
    </figure>
  </template>
}
