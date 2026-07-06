// @ts-check
import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { trustHTML } from "@ember/template";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

const DEFAULT_COUNT = 1;

/**
 * Reusable loading placeholder. Renders one or more shimmer items shaped by
 * `@variant` (a text line, a rectangle, or a circle) and sized to reserve the
 * space the real content will occupy, so revealing the content doesn't shift
 * the surrounding layout.
 *
 * A lone `text` bar takes the inherited line box (`1lh`), matching a real
 * one-line element; stacked text lines drop to ink height (`1em`) spaced one
 * line-height apart, so a paragraph reads as separate lines. Either way the
 * sizing follows the surrounding typography, so a skeleton in a given context
 * (e.g. a heading) needs no hard-coded height or gap. `@lastLineWidth` narrows
 * a multi-line block's final line the way a real paragraph's does.
 *
 * The shimmer comes from the shared `.placeholder-animation` class, which only
 * paints under `prefers-reduced-motion: no-preference`. The items therefore
 * keep a static fill underneath (from the scss) so the placeholder still reads
 * when the animation is suppressed (reduced motion, or `@animated={{false}}`).
 *
 * The consumer's `...attributes` are forwarded to the wrapper element.
 *
 * @extends {Component<{
 *   Args: {
 *     count?: number,
 *     variant?: string,
 *     animated?: boolean,
 *     width?: string,
 *     height?: string,
 *     radius?: string,
 *     size?: string,
 *     lastLineWidth?: string,
 *   },
 *   Element: HTMLDivElement,
 * }>}
 */
export default class DSkeleton extends Component {
  /**
   * The variant, defaulting to a text line. Stamped on both the wrapper and
   * each item so the scss can key variant-specific defaults off it.
   *
   * @returns {string} The variant name.
   */
  get variant() {
    return this.args.variant ?? "text";
  }

  /**
   * Whether more than one item is stacked, so the scss can treat a stack
   * differently from a lone bar (e.g. stacked text lines drop from a full line
   * box to ink height so they read as separate lines).
   *
   * @returns {boolean} `true` when there is more than one item.
   */
  get multiline() {
    return this.items.length > 1;
  }

  /**
   * The placeholder items to render, one per `@count` (at least one), each with
   * its own inline dimensions. Every item shares `@width`/`@height`, except the
   * last takes `@lastLineWidth` instead when it is set and there is more than
   * one item — a tapered final paragraph line.
   *
   * @returns {Array<{style: (ReturnType<typeof trustHTML>|undefined)}>} The
   *   `{{#each}}` source, one entry per item.
   */
  get items() {
    const requested = this.args.count ?? DEFAULT_COUNT;
    const count = Math.max(1, Math.floor(requested));
    return Array.from({ length: count }, (_, index) => ({
      style: this.#styleFor(index, count),
    }));
  }

  /**
   * The shared class applied to every item: the base item class, its variant
   * modifier, and the shimmer class when animated.
   *
   * @returns {string} The space-separated class list.
   */
  get itemClass() {
    const classes = ["d-skeleton__item", `d-skeleton__item--${this.variant}`];

    if (this.args.animated ?? true) {
      classes.push("placeholder-animation");
    }

    return classes.join(" ");
  }

  /**
   * The per-item dimension tokens, emitted as inline custom properties (not the
   * `width`/`height`/`border-radius` properties themselves) so the stylesheet
   * owns the property mapping and can derive from them. Inline custom properties
   * override the variant defaults for this item. `@size` is a shorthand that
   * makes a square (used for circles); explicit `@width`/`@height` win over it.
   * In a multi-line block the last item takes `@lastLineWidth` instead of
   * `@width`, so it renders shorter than the lines above it.
   *
   * @param {number} index - The item's position.
   * @param {number} total - The total number of items.
   * @returns {ReturnType<typeof trustHTML>|undefined} The style string, or
   *   `undefined` when no dimension is set (the variant's scss tokens apply).
   */
  #styleFor(index, total) {
    const { width, height, radius, size, lastLineWidth } = this.args;
    const declarations = [];

    const isLastOfMany = total > 1 && index === total - 1;
    const resolvedWidth =
      isLastOfMany && lastLineWidth != null ? lastLineWidth : (width ?? size);
    const resolvedHeight = height ?? size;

    if (resolvedWidth != null) {
      declarations.push(`--d-skeleton-item-width:${resolvedWidth}`);
    }
    if (resolvedHeight != null) {
      declarations.push(`--d-skeleton-item-height:${resolvedHeight}`);
    }
    if (radius != null) {
      declarations.push(`--d-skeleton-radius:${radius}`);
    }

    return declarations.length ? trustHTML(declarations.join(";")) : undefined;
  }

  <template>
    <div
      class={{dConcatClass
        "d-skeleton"
        (concat "d-skeleton--" this.variant)
        (if this.multiline "d-skeleton--multiline")
      }}
      aria-hidden="true"
      ...attributes
    >
      {{#each this.items key="@index" as |item|}}
        <div class={{this.itemClass}} style={{item.style}}></div>
      {{/each}}
    </div>
  </template>
}
