// @ts-check
import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";

const DEFAULT_COUNT = 1;

/**
 * Reusable loading placeholder. Renders one or more shimmer items shaped by
 * `@variant` (a text line, a rectangle, or a circle) and sized to reserve the
 * space the real content will occupy, so revealing the content doesn't shift
 * the surrounding layout.
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
 *   },
 *   Element: HTMLDivElement,
 * }>}
 */
export default class DSkeleton extends Component {
  /**
   * The placeholder items to render, one per `@count` (at least one).
   *
   * @returns {number[]} An index array used as the `{{#each}}` source.
   */
  get items() {
    const requested = this.args.count ?? DEFAULT_COUNT;
    const count = Math.max(1, Math.floor(requested));
    return Array.from({ length: count }, (_, index) => index);
  }

  /**
   * The shared class applied to every item: the base item class, its variant
   * modifier, and the shimmer class when animated.
   *
   * @returns {string} The space-separated class list.
   */
  get itemClass() {
    const variant = this.args.variant ?? "text";
    const classes = ["d-skeleton__item", `d-skeleton__item--${variant}`];

    if (this.args.animated ?? true) {
      classes.push("placeholder-animation");
    }

    return classes.join(" ");
  }

  /**
   * The inline dimensions for each item. `@size` is a shorthand that makes a
   * square (used for circles); explicit `@width`/`@height` win over it.
   *
   * @returns {ReturnType<typeof trustHTML>|undefined} The style string, or
   *   `undefined` when no dimension is set (the variant's scss sizing applies).
   */
  get style() {
    const { width, height, radius, size } = this.args;
    const declarations = [];

    const resolvedWidth = width ?? size;
    const resolvedHeight = height ?? size;

    if (resolvedWidth != null) {
      declarations.push(`width:${resolvedWidth}`);
    }
    if (resolvedHeight != null) {
      declarations.push(`height:${resolvedHeight}`);
    }
    if (radius != null) {
      declarations.push(`border-radius:${radius}`);
    }

    return declarations.length ? trustHTML(declarations.join(";")) : undefined;
  }

  <template>
    <div class="d-skeleton" aria-hidden="true" ...attributes>
      {{#each this.items key="@index"}}
        <div class={{this.itemClass}} style={{this.style}}></div>
      {{/each}}
    </div>
  </template>
}
