// @ts-check
import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

/**
 * Standalone media card for podcast / video / article promos. One
 * instance = one card; build a row by dropping multiple `ve:media-card`
 * blocks into a `ve:layout` grid.
 *
 * Optional decorative image or solid background, top region with
 * avatar / name / role, bottom region with badge / title / single CTA
 * link. All copy fields start empty so the block doesn't carry any
 * theme-specific placeholder content into a fresh insert.
 */
@block("ve:media-card", {
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
        label: i18n("visual_editor.inspector.media_card.avatar_url"),
      },
    },
    name: {
      type: "string",
      default: "",
      ui: {
        label: i18n("visual_editor.inspector.media_card.name"),
      },
    },
    role: {
      type: "string",
      default: "",
      ui: {
        label: i18n("visual_editor.inspector.media_card.role"),
      },
    },
    badgeIcon: {
      type: "string",
      default: "",
      ui: {
        control: "icon",
        label: i18n("visual_editor.inspector.media_card.badge_icon"),
      },
    },
    badgeLabel: {
      type: "string",
      default: "",
      ui: {
        label: i18n("visual_editor.inspector.media_card.badge_label"),
      },
    },
    title: {
      type: "string",
      default: "",
      ui: {
        control: "textarea",
        label: i18n("visual_editor.inspector.media_card.title"),
      },
    },
    ctaLabel: {
      type: "string",
      default: "",
      ui: {
        label: i18n("visual_editor.inspector.media_card.cta_label"),
      },
    },
    ctaHref: {
      type: "string",
      default: "",
      ui: {
        control: "url",
        label: i18n("visual_editor.inspector.media_card.cta_href"),
      },
    },
    backgroundColor: {
      type: "string",
      default: "",
      ui: {
        control: "color",
        group: "Advanced",
        label: i18n("visual_editor.inspector.media_card.background_color"),
        helpText: i18n(
          "visual_editor.inspector.media_card.background_color_help"
        ),
      },
    },
    imageUrl: {
      type: "string",
      default: "",
      ui: {
        control: "url",
        group: "Advanced",
        label: i18n("visual_editor.inspector.media_card.image_url"),
        helpText: i18n("visual_editor.inspector.media_card.image_url_help"),
      },
    },
  },
  previewArgs: {
    name: "Name",
    role: "Role",
    badgeIcon: "star",
    badgeLabel: "Featured",
    title: "A short headline describing this card",
    ctaLabel: "Learn more",
    ctaHref: "#",
  },
})
export default class VEMediaCard extends Component {
  get backdropStyle() {
    if (this.args.imageUrl) {
      return trustHTML(`background-image: url("${this.args.imageUrl}")`);
    }
    if (this.args.backgroundColor) {
      return trustHTML(`background-color: ${this.args.backgroundColor}`);
    }
    return null;
  }

  <template>
    <div class="ve-media-card">
      {{#if this.backdropStyle}}
        <div class="ve-media-card__backdrop" style={{this.backdropStyle}}></div>
      {{/if}}

      <div class="ve-media-card__top">
        {{#if @avatarUrl}}
          <img class="ve-media-card__avatar" src={{@avatarUrl}} alt={{@name}} />
        {{/if}}

        <div class="ve-media-card__identity">
          {{#if @name}}
            <span class="ve-media-card__name">{{@name}}</span>
          {{/if}}
          {{#if @role}}
            <span class="ve-media-card__role">{{@role}}</span>
          {{/if}}
        </div>
      </div>

      <div class="ve-media-card__bottom">
        {{#if @badgeLabel}}
          <span class="ve-media-card__badge">
            {{#if @badgeIcon}}
              {{dIcon @badgeIcon}}
            {{/if}}
            <span class="ve-media-card__badge-label">{{@badgeLabel}}</span>
          </span>
        {{/if}}

        {{#if @title}}
          <h4 class="ve-media-card__title">{{@title}}</h4>
        {{/if}}

        {{#if @ctaHref}}
          <a class="ve-media-card__cta" href={{@ctaHref}}>
            {{@ctaLabel}}
          </a>
        {{/if}}
      </div>
    </div>
  </template>
}
