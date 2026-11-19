import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { isTrustedHTML, type TrustedHTML } from "@ember/template";
import type { ComponentLike } from "@glint/template";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";

interface DEmptyStateSignature {
  Args: {
    /** A name for this empty state, added to the container as a `--<identifier>` class. */
    identifier?: string;

    /**
     * The illustration shown above the title: a component that renders an SVG, or
     * trusted markup. It takes precedence over `@icon`.
     */
    svgContent?: ComponentLike | TrustedHTML | string;

    /** The ID of an icon shown in place of an illustration. */
    icon?: string;

    /** The title of the empty state. */
    title?: string;

    /** The text below the title. */
    body?: string | TrustedHTML;

    /** The label of a call-to-action button. Without it, no button is shown. */
    ctaLabel?: string;

    /** Called when the call-to-action button is pressed. */
    ctaAction?: () => void;

    /** Whether the call-to-action button is disabled. */
    ctaDisabled?: boolean;

    /** A URL the call-to-action button links to. */
    ctaHref?: string;

    /** The ID of an icon shown on the call-to-action button. */
    ctaIcon?: string;

    /** A route the call-to-action button transitions to. */
    ctaRoute?: string;

    /** A tip shown at the bottom. The `tip` block takes precedence over it. */
    tipText?: string | TrustedHTML;

    /** The ID of an icon shown before the tip. */
    tipIcon?: string;
  };

  Element: HTMLDivElement;

  Blocks: {
    /** Custom content for the tip, rendered in place of `@tipText`. */
    tip: [];
  };
}

/**
 * Tells markup and text apart from a component.
 *
 * @param content - The illustration.
 * @returns Whether the illustration is markup or text.
 */
function isMarkup(content: unknown): content is TrustedHTML | string {
  return typeof content === "string" || isTrustedHTML(content);
}

export default class DEmptyState extends Component<DEmptyStateSignature> {
  /**
   * The illustration when it is a component.
   *
   * @returns The component, or `undefined` when `@svgContent` is markup or text.
   */
  get svgComponent() {
    const content = this.args.svgContent;
    return isMarkup(content) ? undefined : content;
  }

  /**
   * The illustration when it is markup or text.
   *
   * @returns The markup or text, or `undefined` when `@svgContent` is a component.
   */
  get svgMarkup() {
    const content = this.args.svgContent;
    return isMarkup(content) ? content : undefined;
  }

  <template>
    <div
      class="empty-state__container
        {{if @identifier (concat '--' @identifier)}}
        {{if (or @svgContent @icon) '--with-image' '--text-only'}}"
      ...attributes
    >
      <div class="empty-state">
        {{#if @svgContent}}
          <div class="empty-state__image">
            {{#if this.svgComponent}}
              <this.svgComponent />
            {{else}}
              {{this.svgMarkup}}
            {{/if}}
          </div>
        {{else if @icon}}
          <div class="empty-state__image --icon">
            {{dIcon @icon}}
          </div>
        {{/if}}

        {{#if @title}}
          <div class="empty-state__title" data-test-title>{{@title}}</div>
        {{/if}}

        {{#if @body}}
          <div class="empty-state__body">
            <p data-test-body>{{@body}}</p>
          </div>
        {{/if}}

        {{#if @ctaLabel}}
          <div class="empty-state__cta">
            <DButton
              class="btn-primary"
              @action={{@ctaAction}}
              @disabled={{@ctaDisabled}}
              @href={{@ctaHref}}
              @icon={{@ctaIcon}}
              @route={{@ctaRoute}}
              @translatedLabel={{@ctaLabel}}
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
  </template>
}
