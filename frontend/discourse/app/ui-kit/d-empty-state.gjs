// @ts-check
import { concat } from "@ember/helper";
import { or } from "discourse/truth-helpers";
/** @type {import("discourse/ui-kit/d-button.gjs").default} */
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";

/**
 * The standard "nothing to show here" placeholder. Used when a list, table, or
 * dashboard pane has no items — combines an optional SVG illustration, a
 * title and body of copy, a primary call-to-action button, and an optional
 * tip line. Prefer this over hand-rolled empty states so the visual language
 * stays consistent across the app.
 *
 * The CTA section accepts the same `@action` / `@href` / `@route` triplet as
 * `DButton` and is rendered as a primary button. The "tip" slot can either be
 * a plain string via `@tipText` or richer markup via the `:tip` named block.
 *
 * @example
 * <DEmptyState
 *   @identifier="bookmarks"
 *   @title={{i18n "bookmarks.none.title"}}
 *   @body={{i18n "bookmarks.none.body"}}
 *   @ctaLabel={{i18n "bookmarks.add"}}
 *   @ctaAction={{this.addBookmark}}
 *   @ctaIcon="plus"
 * />
 */

/**
 * @typedef DEmptyStateSignature
 *
 * @property {object} Args
 *
 * @property {string} [Args.identifier] A short identifier appended to the container class (`empty-state__container--<identifier>`). Use to target the empty state with feature-specific CSS without inventing a wrapper.
 * @property {unknown} [Args.svgContent] Pre-rendered SVG content (a `SafeString` or trusted HTML) for the illustration above the title. Use `htmlSafe()` for inline SVG sources.
 * @property {string} [Args.title] Translated title rendered above the body. Pass through `i18n()` at the call-site.
 * @property {string} [Args.body] Translated body copy.
 * @property {string} [Args.ctaLabel] Translated label for the call-to-action button. When omitted, no button renders.
 * @property {string} [Args.ctaIcon] FontAwesome icon name for the CTA button.
 * @property {Function} [Args.ctaAction] Click handler for the CTA. Mutually exclusive with `@ctaHref` and `@ctaRoute` (per `DButton`).
 * @property {string} [Args.ctaHref] External URL for the CTA. Renders the button as an anchor.
 * @property {string} [Args.ctaRoute] Ember route name for the CTA. Triggers `router.transitionTo` on click.
 * @property {string} [Args.tipText] Translated tip copy rendered below the CTA. Use when the tip is a plain string; for richer content use the `:tip` named block instead.
 * @property {string} [Args.tipIcon] FontAwesome icon name rendered before the tip content.
 *
 * @property {HTMLDivElement} Element
 *
 * @property {object} Blocks
 * @property {[]} Blocks.tip Optional named block for richer tip content (markup, links). Mutually exclusive with `@tipText` — when both are passed, the block wins.
 */

/** @type {import("@ember/component/template-only").TOC<DEmptyStateSignature>} */
const DEmptyState = <template>
  {{! @glint-nocheck: forwards args to DButton whose dynamic-tag template surfaces unknown-element complaints in consumers }}
  <div
    class="empty-state__container
      {{if @identifier (concat '--' @identifier)}}
      {{if @svgContent '--with-image' '--text-only'}}"
  >
    <div class="empty-state">
      {{#if @svgContent}}
        <div class="empty-state__image">
          {{@svgContent}}
        </div>
      {{/if}}

      {{#if @title}}
        <div data-test-title class="empty-state__title">{{@title}}</div>
      {{/if}}

      {{#if @body}}
        <div class="empty-state__body">
          <p data-test-body>{{@body}}</p>
        </div>
      {{/if}}

      {{#if @ctaLabel}}
        <div class="empty-state__cta">
          <DButton
            @action={{@ctaAction}}
            @href={{@ctaHref}}
            @route={{@ctaRoute}}
            @translatedLabel={{@ctaLabel}}
            @icon={{@ctaIcon}}
            class="btn-primary"
          />
        </div>
      {{/if}}

      {{#if (or @tipText (has-block "tip"))}}
        <div class="empty-state__tip">
          {{#if @tipIcon}}
            {{dIcon @tipIcon}}
          {{/if}}
          {{#if (has-block "tip")}}
            {{yield to="tip"}}
          {{else}}
            {{@tipText}}
          {{/if}}
        </div>
      {{/if}}
    </div>
  </div>
</template>;

export default DEmptyState;
