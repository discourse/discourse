// @ts-check
import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";
import {
  HEX_COLOR_PATTERN,
  ICON_NAME_PATTERN,
  URL_PATTERN,
} from "discourse/lib/blocks";
import RichTextRenderer from "discourse/lib/blocks/-internals/rich-text-renderer";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const VALID_VARIANTS = ["vertical", "horizontal"];

/**
 * A content card: an optional image with a title, meta line, and body, laid
 * out vertically (image on top) or horizontally (image beside the text). Drop
 * several into a `layout` in Tiles mode to build a responsive card grid.
 *
 * When an `href` is set the whole card becomes a single link via the
 * stretched-link affordance (a positioned anchor covering the card) instead of
 * wrapping the content in an `<a>` — so the markup stays valid and any inner
 * links remain clickable. `linkLabel` supplies the link's accessible name.
 *
 * All copy fields start empty so a fresh insert carries no placeholder
 * content; the editor reveals each field for inline editing.
 */
@block("card", {
  thumbnail: () => import("discourse/blocks/thumbnails/card"),
  displayName: "Card",
  icon: "id-card",
  category: "Content",
  description:
    "A card with an image, title, meta, and body — optionally linked as a whole.",
  args: {
    image: {
      type: "image",
      allowDark: true,
      allowResize: false,
      aspectRatio: "auto",
      defaultFit: "cover",
      ui: { label: i18n("blocks.builtin.card.image") },
    },
    icon: {
      type: "string",
      pattern: ICON_NAME_PATTERN,
      ui: { control: "icon", label: i18n("blocks.builtin.card.icon") },
    },
    title: {
      type: "richInline",
      ui: {
        control: "rich-inline",
        schema: "paragraph",
        label: i18n("blocks.builtin.card.title"),
      },
    },
    meta: {
      type: "richInline",
      ui: {
        control: "rich-inline",
        schema: "plain",
        label: i18n("blocks.builtin.card.meta"),
      },
    },
    body: {
      type: "richInline",
      ui: {
        control: "rich-inline",
        schema: "paragraph",
        label: i18n("blocks.builtin.card.body"),
      },
    },
    variant: {
      type: "string",
      default: "vertical",
      enum: VALID_VARIANTS,
      ui: {
        control: "radio-group",
        label: i18n("blocks.builtin.card.variant"),
      },
    },
    backgroundColor: {
      type: "string",
      pattern: HEX_COLOR_PATTERN,
      ui: {
        control: "color",
        group: "Appearance",
        label: i18n("blocks.builtin.card.background_color"),
      },
    },
    href: {
      type: "string",
      pattern: URL_PATTERN,
      ui: {
        control: "url",
        group: "Link",
        label: i18n("blocks.builtin.card.href"),
        helpText: i18n("blocks.builtin.card.href_help"),
      },
    },
    linkLabel: {
      type: "string",
      default: "",
      ui: {
        group: "Link",
        label: i18n("blocks.builtin.card.link_label"),
        helpText: i18n("blocks.builtin.card.link_label_help"),
        conditional: { arg: "href", notEmpty: true },
      },
    },
    external: {
      type: "boolean",
      default: false,
      ui: {
        control: "toggle",
        group: "Link",
        label: i18n("blocks.builtin.card.external"),
        helpText: i18n("blocks.builtin.card.external_help"),
        conditional: { arg: "href", notEmpty: true },
      },
    },
  },
})
export default class Card extends Component {
  /**
   * Optional solid background, emitted as a CSS custom property the stylesheet
   * consumes (kept off the inline style declaration so a theme can override).
   *
   * @returns {ReturnType<typeof trustHTML> | null}
   */
  get backdropStyle() {
    if (this.args.backgroundColor) {
      return trustHTML(`--d-block-card-bg-color: ${this.args.backgroundColor}`);
    }
    return null;
  }

  /**
   * BEM class list with the vertical / horizontal variant modifier.
   *
   * @returns {string}
   */
  get className() {
    const variant = VALID_VARIANTS.includes(this.args.variant)
      ? this.args.variant
      : "vertical";
    return `d-block-card d-block-card--${variant}`;
  }

  <template>
    <div class={{this.className}} style={{this.backdropStyle}}>
      {{! The image arg always renders a marker for edit tooling to anchor a
          drop target to: the real image once a URL is set, an empty slot
          otherwise. The empty slot collapses on the reader page. }}
      {{#if @image.url}}
        <img
          class="d-block-card__image"
          src={{@image.url}}
          alt={{@title}}
          data-block-arg="image"
        />
      {{else}}
        <div
          class="d-block-card__image d-block-card__image--empty"
          data-block-arg="image"
          data-drop-fills-block
        ></div>
      {{/if}}

      <div class="d-block-card__body">
        {{#if @icon}}
          <div class="d-block-card__icon" data-block-arg="icon">
            {{dIcon @icon}}
          </div>
        {{/if}}

        <RichTextRenderer
          @arg="title"
          @schema="paragraph"
          @value={{@title}}
          @placeholder={{i18n "blocks.builtin.placeholders.card_title"}}
          as |R|
        >
          <h3
            class="d-block-card__title
              {{if R.isEmpty 'd-block-card__title--empty'}}"
          >
            <R.Content />
          </h3>
        </RichTextRenderer>

        <RichTextRenderer
          @arg="meta"
          @schema="plain"
          @value={{@meta}}
          @placeholder={{i18n "blocks.builtin.placeholders.card_meta"}}
          as |R|
        >
          <span
            class="d-block-card__meta
              {{if R.isEmpty 'd-block-card__meta--empty'}}"
          >
            <R.Content />
          </span>
        </RichTextRenderer>

        <RichTextRenderer
          @arg="body"
          @schema="paragraph"
          @value={{@body}}
          @placeholder={{i18n "blocks.builtin.placeholders.card_body"}}
          as |R|
        >
          <p
            class="d-block-card__text
              {{if R.isEmpty 'd-block-card__text--empty'}}"
          >
            <R.Content />
          </p>
        </RichTextRenderer>
      </div>

      {{#if @href}}
        <a
          class="d-block-stretched-link"
          href={{@href}}
          target={{if @external "_blank"}}
          rel={{if @external "noopener"}}
          aria-label={{@linkLabel}}
          data-block-arg="href"
        ></a>
      {{/if}}
    </div>
  </template>
}
