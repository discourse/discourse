// @ts-check
import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";
import { i18n } from "discourse-i18n";
import IconRenderer from "../components/icon-renderer";
import RichTextRenderer from "../components/rich-text-renderer";

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
    avatarUrl: {
      type: "string",
      default: "",
      ui: {
        control: "url",
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
      default: "",
      ui: {
        control: "icon",
        label: i18n("wireframe.inspector.media_card.badge_icon"),
      },
    },
    badgeLabel: {
      type: "richInline",
      ui: {
        control: "rich-inline",
        label: i18n("wireframe.inspector.media_card.badge_label"),
      },
    },
    title: {
      type: "richInline",
      ui: {
        control: "rich-inline",
        label: i18n("wireframe.inspector.media_card.title"),
      },
    },
    ctaLabel: {
      type: "richInline",
      ui: {
        control: "rich-inline",
        label: i18n("wireframe.inspector.media_card.cta_label"),
      },
    },
    ctaHref: {
      type: "string",
      default: "",
      ui: {
        control: "url",
        label: i18n("wireframe.inspector.media_card.cta_href"),
      },
    },
    backgroundColor: {
      type: "string",
      default: "",
      ui: {
        control: "color",
        group: "Advanced",
        label: i18n("wireframe.inspector.media_card.background_color"),
        helpText: i18n("wireframe.inspector.media_card.background_color_help"),
      },
    },
    imageUrl: {
      type: "string",
      default: "",
      ui: {
        control: "url",
        group: "Advanced",
        label: i18n("wireframe.inspector.media_card.image_url"),
        helpText: i18n("wireframe.inspector.media_card.image_url_help"),
      },
    },
  },
})
export default class WFMediaCard extends Component {
  get backdropStyle() {
    if (this.args.imageUrl) {
      return trustHTML(`background-image: url("${this.args.imageUrl}")`);
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
      {{#if this.backdropStyle}}
        <div class="wf-media-card__backdrop" style={{this.backdropStyle}}></div>
      {{/if}}

      <div class="wf-media-card__top">
        {{#if @avatarUrl}}
          <img class="wf-media-card__avatar" src={{@avatarUrl}} alt={{@name}} />
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
          <IconRenderer @value={{@badgeIcon}} @arg="badgeIcon" />
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
          >
            <R.Content />
          </a>
        </RichTextRenderer>
      </div>
    </div>
  </template>
}
