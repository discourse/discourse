// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { block } from "discourse/blocks";
import cookie from "discourse/lib/cookie";
import getURL from "discourse/lib/get-url";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import RichTextRenderer from "../components/rich-text-renderer";
import { URL_PATTERN } from "../lib/arg-patterns";

const COOKIE_PREFIX = "discourse-wireframe-cta-dismissed";

/**
 * Banner with title, body text, an optional CTA button, and an optional
 * dismiss action. Per-banner dismissal is keyed by the `cookieKey` arg
 * (empty string means "all dismissable instances share state").
 *
 * Route-gating (homepage only, hide for logged-in users, etc.) lives in
 * the editor's conditions system — the block itself just renders.
 */
@block("wf:cta-banner", {
  displayName: "CTA banner",
  icon: "bullhorn",
  category: "Content",
  description:
    "A banner with title, body text, optional CTA button, and optional dismiss.",
  args: {
    title: {
      type: "richInline",
      required: true,
      ui: {
        control: "rich-inline",
        label: i18n("wireframe.inspector.cta_banner.title"),
      },
    },
    content: {
      type: "richInline",
      ui: {
        control: "rich-inline",
        label: i18n("wireframe.inspector.cta_banner.content"),
      },
    },
    linkLabel: {
      type: "string",
      required: true,
      ui: {
        label: i18n("wireframe.inspector.cta_banner.link_label"),
      },
    },
    linkHref: {
      type: "string",
      required: true,
      pattern: URL_PATTERN,
      ui: {
        control: "url",
        label: i18n("wireframe.inspector.cta_banner.link_href"),
      },
    },
    dismissable: {
      type: "boolean",
      default: false,
      ui: {
        control: "toggle",
        label: i18n("wireframe.inspector.cta_banner.dismissable"),
      },
    },
    cookieKey: {
      type: "string",
      ui: {
        label: i18n("wireframe.inspector.cta_banner.cookie_key"),
        helpText: i18n("wireframe.inspector.cta_banner.cookie_key_help"),
        group: "Advanced",
        conditional: { arg: "dismissable", equals: true },
      },
    },
  },
  validate(args) {
    // `requires` is value-agnostic (any non-undefined value satisfies it),
    // but `dismissable` defaults to `false` so it's always considered
    // provided. We only want to demand a `cookieKey` when dismissable is
    // toggled ON — otherwise the conditional UI hides the field anyway.
    if (args.dismissable === true && !args.cookieKey) {
      return i18n("wireframe.validation.cta_banner.cookie_key_required");
    }
  },
})
export default class WFCTABanner extends Component {
  @tracked dismissed = document.cookie.includes(`${this.cookieName}=dismissed`);

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

  get shouldShow() {
    return !(this.args.dismissable && this.dismissed);
  }

  get hasActions() {
    return !!(this.args.linkHref || this.args.dismissable);
  }

  @action
  dismissBanner() {
    const expires = new Date();
    expires.setMonth(expires.getMonth() + 3);
    cookie(this.cookieName, "dismissed", {
      path: getURL("/"),
      secure: true,
      expires,
    });
    this.dismissed = true;
  }

  <template>
    {{#if this.shouldShow}}
      <div class="wf-cta-banner">
        <div class="wf-cta-banner__content">
          <RichTextRenderer
            @arg="title"
            @schema="heading"
            @value={{@title}}
            @placeholder={{i18n "wireframe.placeholders.cta_banner_title"}}
            as |R|
          >
            <h3
              class="wf-cta-banner__title
                {{if R.isEmpty 'wf-cta-banner__title--empty'}}"
            >
              <R.Content />
            </h3>
          </RichTextRenderer>
          <RichTextRenderer
            @arg="content"
            @schema="paragraph"
            @value={{@content}}
            @placeholder={{i18n "wireframe.placeholders.cta_banner_content"}}
            as |R|
          >
            <p
              class="wf-cta-banner__text
                {{if R.isEmpty 'wf-cta-banner__text--empty'}}"
            >
              <R.Content />
            </p>
          </RichTextRenderer>
        </div>

        {{#if this.hasActions}}
          <div class="wf-cta-banner__actions">
            {{#if @linkHref}}
              <DButton
                class="btn btn-primary"
                @href={{@linkHref}}
                @translatedLabel={{@linkLabel}}
                data-block-arg="linkHref"
              />
            {{/if}}
            {{#if @dismissable}}
              <DButton
                class="wf-cta-banner__close"
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
