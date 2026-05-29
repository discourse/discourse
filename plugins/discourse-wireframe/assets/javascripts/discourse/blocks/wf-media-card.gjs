// @ts-check
import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import RichTextRenderer from "../components/rich-text-renderer";
import {
  HEX_COLOR_PATTERN,
  ICON_NAME_PATTERN,
  URL_PATTERN,
} from "../lib/arg-patterns";

/**
 * Standalone media card for podcast / video / article promos. One
 * instance = one card; build a row by dropping multiple `wf:media-card`
 * blocks into a `wf:layout` grid.
 *
 * Optional decorative image or solid background, top region with
 * avatar / name / role, bottom region with badge / title / single CTA
 * link. All copy fields start empty so the block doesn't carry any
 * theme-specific placeholder content into a fresh insert.
 */
@block("wf:media-card", {
  displayName: "Media card",
  icon: "photo-film",
  category: "Content",
  description:
    "Featured media card with avatar, name, badge, title, and CTA link.",
  args: {
    avatar: {
      type: "image",
      allowDark: false,
      allowResize: false,
      aspectRatio: 1,
      defaultFit: "cover",
      ui: {
        label: i18n("wireframe.inspector.media_card.avatar_url"),
      },
    },
    name: {
      type: "richInline",
      ui: {
        control: "rich-inline",
        label: i18n("wireframe.inspector.media_card.name"),
      },
    },
    role: {
      type: "richInline",
      ui: {
        control: "rich-inline",
        label: i18n("wireframe.inspector.media_card.role"),
      },
    },
    badgeIcon: {
      type: "string",
      pattern: ICON_NAME_PATTERN,
      ui: {
        control: "icon",
        label: i18n("wireframe.inspector.media_card.badge_icon"),
      },
    },
    badgeLabel: {
      type: "richInline",
      required: true,
      ui: {
        control: "rich-inline",
        label: i18n("wireframe.inspector.media_card.badge_label"),
      },
    },
    title: {
      type: "richInline",
      required: true,
      ui: {
        control: "rich-inline",
        label: i18n("wireframe.inspector.media_card.title"),
      },
    },
    ctaLabel: {
      type: "richInline",
      required: true,
      ui: {
        control: "rich-inline",
        label: i18n("wireframe.inspector.media_card.cta_label"),
      },
    },
    ctaHref: {
      type: "string",
      required: true,
      pattern: URL_PATTERN,
      ui: {
        control: "url",
        label: i18n("wireframe.inspector.media_card.cta_href"),
      },
    },
    backgroundColor: {
      type: "string",
      pattern: HEX_COLOR_PATTERN,
      ui: {
        control: "color",
        group: "Advanced",
        label: i18n("wireframe.inspector.media_card.background_color"),
        helpText: i18n("wireframe.inspector.media_card.background_color_help"),
      },
    },
    image: {
      type: "image",
      allowDark: true,
      allowResize: true,
      aspectRatio: "auto",
      defaultFit: "cover",
      ui: {
        group: "Advanced",
        label: i18n("wireframe.inspector.media_card.image_url"),
        helpText: i18n("wireframe.inspector.media_card.image_url_help"),
      },
    },
  },
})
export default class WFMediaCard extends Component {
  /**
   * Inline style for the decorative backdrop. The cover image is painted
   * via `background-image` (not an `<img>`) so it can layer behind the
   * card content without affecting layout. When the image arg carries a
   * `dark` variant we emit a second CSS custom property; the SCSS picks
   * it up under `@media (prefers-color-scheme: dark)`.
   *
   * @returns {ReturnType<typeof trustHTML> | null}
   */
  get backdropStyle() {
    const image = this.args.image;
    if (image?.url) {
      const lightUrl = cssUrl(image.url);
      const darkUrl = image.dark?.url ? cssUrl(image.dark.url) : null;
      const decls = [`--wf-media-card-bg-light: ${lightUrl}`];
      if (darkUrl) {
        decls.push(`--wf-media-card-bg-dark: ${darkUrl}`);
      }
      return trustHTML(decls.join("; "));
    }
    if (this.args.backgroundColor) {
      return trustHTML(`background-color: ${this.args.backgroundColor}`);
    }
    return null;
  }

  /**
   * The badge wraps both the icon and the label, so its emptiness is
   * compound — collapse the badge on the live site only when BOTH are
   * empty. Computed in JS (instead of via `(and (not @badgeIcon) …)` in
   * the template) so we don't end up with a CSS `:has()` rule on the
   * live render path AND don't trip the ember-eslint-parser's
   * Glimmer-attribute helper-nesting bug.
   *
   * @returns {boolean}
   */
  get isBadgeCollapsed() {
    if (this.args.badgeIcon) {
      return false;
    }
    const label = this.args.badgeLabel;
    if (typeof label === "string") {
      return !label;
    }
    return (
      !label || !Array.isArray(label.content) || label.content.length === 0
    );
  }

  <template>
    <div class="wf-media-card">
      {{! Always render the backdrop marker so the chrome can anchor an
          image overlay over it even with no background set. The empty
          modifier collapses it on the live site; the chrome reveals it on
          the canvas. data-drop-passive marks it as sitting behind the card
          content, so its overlay stays click-through and never swallows
          clicks meant for the title or CTA. }}
      <div
        class="wf-media-card__backdrop
          {{unless this.backdropStyle 'wf-media-card__backdrop--empty'}}"
        style={{this.backdropStyle}}
        data-block-arg="image"
        data-drop-passive
      ></div>

      <div class="wf-media-card__top">
        {{! The avatar arg always renders a marker for the chrome to
            anchor its overlay to: the real image once a URL is set, an
            empty slot otherwise. The two are mutually exclusive so the
            per-arg overlay never resolves the wrong node. The empty slot
            collapses on the live site and is revealed on the canvas. }}
        {{#if @avatar.url}}
          <img
            class="wf-media-card__avatar"
            src={{@avatar.url}}
            alt={{@name}}
            data-block-arg="avatar"
          />
        {{else}}
          <div
            class="wf-media-card__avatar wf-media-card__avatar--empty"
            data-block-arg="avatar"
          ></div>
        {{/if}}

        <div class="wf-media-card__identity">
          <RichTextRenderer
            @arg="name"
            @schema="plain"
            @value={{@name}}
            @placeholder={{i18n "wireframe.placeholders.media_card_name"}}
            as |R|
          >
            <span class="wf-media-card__name">
              <R.Content />
            </span>
          </RichTextRenderer>
          <RichTextRenderer
            @arg="role"
            @schema="plain"
            @value={{@role}}
            @placeholder={{i18n "wireframe.placeholders.media_card_role"}}
            as |R|
          >
            <span class="wf-media-card__role">
              <R.Content />
            </span>
          </RichTextRenderer>
        </div>
      </div>

      <div class="wf-media-card__bottom">
        {{! Badge wrapper is always rendered so the label is reachable
            for inline editing on the canvas. The `--empty` modifier
            collapses the badge on the live site only when BOTH icon
            and label are empty (compound condition computed in JS via
            `this.isBadgeCollapsed`, not via a CSS `:has()` rule — the
            live render path needs to stay cheap). The chrome's
            `--selected` override re-shows the badge on the canvas. }}
        <span
          class="wf-media-card__badge
            {{if this.isBadgeCollapsed 'wf-media-card__badge--empty'}}"
        >
          {{#if @badgeIcon}}
            <span class="wf-inline-icon" data-block-arg="badgeIcon">
              {{dIcon @badgeIcon}}
            </span>
          {{/if}}
          <RichTextRenderer
            @arg="badgeLabel"
            @schema="plain"
            @value={{@badgeLabel}}
            @placeholder={{i18n
              "wireframe.placeholders.media_card_badge_label"
            }}
            as |R|
          >
            <span class="wf-media-card__badge-label">
              <R.Content />
            </span>
          </RichTextRenderer>
        </span>

        <RichTextRenderer
          @arg="title"
          @schema="paragraph"
          @value={{@title}}
          @placeholder={{i18n "wireframe.placeholders.media_card_title"}}
          as |R|
        >
          <h4
            class="wf-media-card__title
              {{if R.isEmpty 'wf-media-card__title--empty'}}"
          >
            <R.Content />
          </h4>
        </RichTextRenderer>

        {{! CTA wrapper is always rendered so the label is reachable for
            inline editing on the canvas. The `--empty` BEM modifier hides
            the wrapper on live when the label is empty; the chrome reveal
            re-shows it on the canvas. }}
        <RichTextRenderer
          @arg="ctaLabel"
          @schema="plain"
          @value={{@ctaLabel}}
          @placeholder={{i18n "wireframe.placeholders.media_card_cta_label"}}
          as |R|
        >
          <a
            class="wf-media-card__cta
              {{if R.isEmpty 'wf-media-card__cta--empty'}}"
            href={{@ctaHref}}
            data-block-arg="ctaHref"
          >
            <R.Content />
          </a>
        </RichTextRenderer>
      </div>
    </div>
  </template>
}

/**
 * Wraps a URL in CSS `url("...")` syntax with backslash-escaped quotes
 * and backslashes so the value can be safely interpolated into an inline
 * `style` attribute. The URL itself comes from the trusted upload
 * pipeline; this guards against accidental breakage from a stray
 * double-quote in a CDN-rewritten path.
 *
 * @param {string} url
 * @returns {string}
 */
function cssUrl(url) {
  const escaped = url.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
  return `url("${escaped}")`;
}
