// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { block } from "discourse/blocks";
import cookie from "discourse/lib/cookie";
import getURL from "discourse/lib/get-url";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import InlineRichTextRenderer from "../components/inline-rich-text-renderer";

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
      type: "richInline",
      ui: {
        control: "rich-inline",
        label: i18n("visual_editor.inspector.cta_banner.title"),
      },
    },
    content: {
      type: "richInline",
      ui: {
        control: "rich-inline",
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
          <InlineRichTextRenderer
            @arg="title"
            @schema="heading"
            @value={{@title}}
            @placeholder={{i18n "visual_editor.placeholders.cta_banner_title"}}
            as |R|
          >
            <h3
              class="ve-cta-banner__title
                {{if R.isEmpty 've-cta-banner__title--empty'}}"
            >
              <R.Content />
            </h3>
          </InlineRichTextRenderer>
          <InlineRichTextRenderer
            @arg="content"
            @schema="paragraph"
            @value={{@content}}
            @placeholder={{i18n
              "visual_editor.placeholders.cta_banner_content"
            }}
            as |R|
          >
            <p
              class="ve-cta-banner__text
                {{if R.isEmpty 've-cta-banner__text--empty'}}"
            >
              <R.Content />
            </p>
          </InlineRichTextRenderer>
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
