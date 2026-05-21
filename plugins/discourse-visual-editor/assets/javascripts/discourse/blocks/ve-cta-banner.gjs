// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { block } from "discourse/blocks";
import cookie from "discourse/lib/cookie";
import getURL from "discourse/lib/get-url";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

const COOKIE_PREFIX = "discourse-visual-editor-cta-dismissed";

/**
 * Banner with title, body text, an optional CTA button, and an optional
 * dismiss action. Per-banner dismissal is keyed by the `cookieKey` arg
 * (empty string means "all dismissable instances share state").
 *
 * Route-gating (homepage only, hide for logged-in users, etc.) lives in
 * the editor's conditions system — the block itself just renders.
 */
@block("ve:cta-banner", {
  displayName: "CTA banner",
  icon: "bullhorn",
  category: "Content",
  description:
    "A banner with title, body text, optional CTA button, and optional dismiss.",
  args: {
    title: {
      type: "string",
      default: "Welcome",
      ui: {
        label: i18n("visual_editor.inspector.cta_banner.title"),
      },
    },
    content: {
      type: "string",
      default: "Tell readers what they can do here, and why.",
      ui: {
        control: "textarea",
        label: i18n("visual_editor.inspector.cta_banner.content"),
      },
    },
    linkLabel: {
      type: "string",
      default: "",
      ui: {
        label: i18n("visual_editor.inspector.cta_banner.link_label"),
      },
    },
    linkHref: {
      type: "string",
      default: "",
      ui: {
        control: "url",
        label: i18n("visual_editor.inspector.cta_banner.link_href"),
      },
    },
    dismissable: {
      type: "boolean",
      default: false,
      ui: {
        control: "toggle",
        label: i18n("visual_editor.inspector.cta_banner.dismissable"),
      },
    },
    cookieKey: {
      type: "string",
      default: "",
      ui: {
        label: i18n("visual_editor.inspector.cta_banner.cookie_key"),
        helpText: i18n("visual_editor.inspector.cta_banner.cookie_key_help"),
        group: "Advanced",
        conditional: { arg: "dismissable", equals: true },
      },
    },
  },
  previewArgs: {
    title: "Welcome",
    content: "Tell readers what they can do here, and why.",
    linkLabel: "Get started",
    linkHref: "/categories",
  },
})
export default class VECTABanner extends Component {
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
      <div class="ve-cta-banner">
        <div class="ve-cta-banner__content">
          {{#if @title}}
            <h3 class="ve-cta-banner__title">{{@title}}</h3>
          {{/if}}
          {{#if @content}}
            <p class="ve-cta-banner__text">{{@content}}</p>
          {{/if}}
        </div>

        {{#if this.hasActions}}
          <div class="ve-cta-banner__actions">
            {{#if @linkHref}}
              <DButton
                class="btn btn-primary"
                @href={{@linkHref}}
                @translatedLabel={{@linkLabel}}
              />
            {{/if}}
            {{#if @dismissable}}
              <DButton
                class="ve-cta-banner__close"
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
