// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { block } from "discourse/blocks";
import { ICON_NAME_PATTERN, URL_PATTERN } from "discourse/lib/blocks";
/** @type {import("discourse/lib/blocks/-internals/rich-text-renderer.gjs")} */
import RichTextRenderer from "discourse/lib/blocks/-internals/rich-text-renderer";
import cookie from "discourse/lib/cookie";
import getURL from "discourse/lib/get-url";
/** @type {import("discourse/ui-kit/d-button.gjs")} */
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const COOKIE_PREFIX = "discourse-cta-dismissed";

/**
 * Banner with title, body text, an optional CTA button, and an optional
 * dismiss action. Per-banner dismissal is keyed by the `cookieKey` arg
 * (empty string means "all dismissable instances share state").
 *
 * Route-gating (homepage only, hide for logged-in users, etc.) lives in
 * the block conditions system — the block itself just renders.
 */
@block("cta-banner", {
  thumbnail:
    /** @type {() => Promise<typeof import("discourse/blocks/thumbnails/cta-banner.gjs")>} */ (
      () => import("discourse/blocks/thumbnails/cta-banner")
    ),
  displayName: "CTA banner",
  icon: "bullhorn",
  category: "Content",
  description:
    "A banner with title, body text, optional CTA button, and optional dismiss.",
  args: {
    icon: {
      type: "string",
      pattern: ICON_NAME_PATTERN,
      ui: { control: "icon", label: i18n("blocks.builtin.cta_banner.icon") },
    },
    title: {
      type: "richInline",
      required: true,
      ui: {
        control: "rich-inline",
        schema: "heading",
        label: i18n("blocks.builtin.cta_banner.title"),
      },
    },
    content: {
      type: "richInline",
      ui: {
        control: "rich-inline",
        schema: "paragraph",
        label: i18n("blocks.builtin.cta_banner.content"),
      },
    },
    linkLabel: {
      type: "string",
      required: true,
      ui: {
        label: i18n("blocks.builtin.cta_banner.link_label"),
      },
    },
    linkHref: {
      type: "string",
      required: true,
      pattern: URL_PATTERN,
      ui: {
        control: "url",
        label: i18n("blocks.builtin.cta_banner.link_href"),
      },
    },
    external: {
      type: "boolean",
      default: false,
      ui: {
        control: "toggle",
        label: i18n("blocks.builtin.cta_banner.external"),
        helpText: i18n("blocks.builtin.cta_banner.external_help"),
      },
    },
    dismissable: {
      type: "boolean",
      default: false,
      ui: {
        control: "toggle",
        label: i18n("blocks.builtin.cta_banner.dismissable"),
      },
    },
    cookieKey: {
      type: "string",
      ui: {
        label: i18n("blocks.builtin.cta_banner.cookie_key"),
        helpText: i18n("blocks.builtin.cta_banner.cookie_key_help"),
        group: "Advanced",
        conditional: { arg: "dismissable", equals: true },
      },
    },
  },
  validate(args) {
    // Custom validation because `required: true` on `cookieKey` would
    // demand it unconditionally — but the field is only meaningful when
    // `dismissable` is on, so we only need the value then.
    if (args.dismissable === true && !args.cookieKey) {
      return i18n("blocks.builtin.cta_banner.cookie_key_required");
    }
  },
})
export default class CtaBanner extends Component {
  @tracked
  _dismissed = document.cookie.includes(`${this.cookieName}=dismissed`);

  /**
   * Per-instance cookie name. Combining a fixed prefix with the
   * author-supplied `cookieKey` (or a static suffix when none is set)
   * keeps the dismissal state local to this banner — two banners can
   * have independent dismiss states by setting different `cookieKey`
   * values.
   */
  get cookieName() {
    const key = this.args.cookieKey?.trim();
    return key ? `${COOKIE_PREFIX}--${key}` : COOKIE_PREFIX;
  }

  /**
   * Whether the banner should be rendered. Hides the banner once the
   * visitor has dismissed it (and dismissal is enabled).
   *
   * @returns {boolean}
   */
  get shouldShow() {
    return !(this.args.dismissable && this._dismissed);
  }

  /**
   * Whether the actions region (link button and/or close button) has
   * anything to render. Used to suppress the actions wrapper entirely
   * when neither a link nor a dismiss button is configured.
   *
   * @returns {boolean}
   */
  get hasActions() {
    return !!(this.args.linkHref || this.args.dismissable);
  }

  /**
   * Persists the dismissal in a cookie scoped to this banner's
   * `cookieName`, with a three-month expiry. Flips `_dismissed` so the
   * banner re-renders empty.
   */
  @action
  dismissBanner() {
    const expires = new Date();
    expires.setMonth(expires.getMonth() + 3);
    cookie(this.cookieName, "dismissed", {
      path: getURL("/"),
      secure: true,
      expires,
    });
    this._dismissed = true;
  }

  <template>
    {{#if this.shouldShow}}
      <div class="d-block-cta-banner">
        <div class="d-block-cta-banner__content">
          {{#if @icon}}
            <div class="d-block-cta-banner__icon" data-block-arg="icon">
              {{dIcon @icon}}
            </div>
          {{/if}}
          <RichTextRenderer
            @arg="title"
            @schema="heading"
            @value={{@title}}
            @placeholder={{i18n "blocks.builtin.placeholders.cta_banner_title"}}
            as |R|
          >
            <h3
              class="d-block-cta-banner__title
                {{if R.isEmpty 'd-block-cta-banner__title--empty'}}"
            >
              <R.Content />
            </h3>
          </RichTextRenderer>
          <RichTextRenderer
            @arg="content"
            @schema="paragraph"
            @value={{@content}}
            @placeholder={{i18n
              "blocks.builtin.placeholders.cta_banner_content"
            }}
            as |R|
          >
            <p
              class="d-block-cta-banner__text
                {{if R.isEmpty 'd-block-cta-banner__text--empty'}}"
            >
              <R.Content />
            </p>
          </RichTextRenderer>
        </div>

        {{#if this.hasActions}}
          <div class="d-block-cta-banner__actions">
            {{#if @linkHref}}
              <DButton
                class="btn btn-primary"
                @href={{@linkHref}}
                @translatedLabel={{@linkLabel}}
                {{! @glint-expect-error: DButton renders an anchor when a link href is set, so the anchor-only target attribute is valid at runtime }}
                target={{if @external "_blank"}}
                rel={{if @external "noopener"}}
                data-block-arg="linkHref"
              />
            {{/if}}
            {{#if @dismissable}}
              <DButton
                class="d-block-cta-banner__close"
                @icon="xmark"
                @action={{this.dismissBanner}}
              />
            {{/if}}
          </div>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
