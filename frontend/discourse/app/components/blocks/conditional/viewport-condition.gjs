import Component from "@glimmer/component";
import { DEBUG } from "@glimmer/env";
import { service } from "@ember/service";
import { block } from "discourse/components/block-outlet";

/**
 * Available viewport breakpoint names.
 * Values match the breakpoints defined in capabilities.viewport.
 *
 * @constant {ReadonlyArray<string>}
 */
const BREAKPOINTS = Object.freeze(["sm", "md", "lg", "xl", "2xl"]);

/**
 * A conditional container block that renders children based on viewport size.
 *
 * Uses the standard Discourse breakpoints from the capabilities service:
 * - sm: >= 40rem (640px)
 * - md: >= 48rem (768px)
 * - lg: >= 64rem (1024px)
 * - xl: >= 80rem (1280px)
 * - 2xl: >= 96rem (1536px)
 *
 * **Note:** For simple show/hide based on viewport, CSS media queries are often
 * more performant. Use this block when you need to completely remove components
 * from the DOM on certain viewports, or when the block content differs significantly
 * between viewports.
 *
 * @component ViewportCondition
 * @param {string} [min] - Minimum breakpoint required (renders at this size and larger)
 * @param {string} [max] - Maximum breakpoint allowed (renders at this size and smaller)
 * @param {boolean} [mobile] - If true, render only on mobile devices; if false, only on non-mobile
 * @param {boolean} [touch] - If true, render only on touch devices; if false, only on non-touch
 *
 * @example
 * // Render only on large screens (lg and up)
 * {
 *   block: ViewportCondition,
 *   args: { min: "lg" },
 *   children: [
 *     { block: BlockDesktopSidebar }
 *   ]
 * }
 *
 * @example
 * // Render only on small screens (below md)
 * {
 *   block: ViewportCondition,
 *   args: { max: "sm" },
 *   children: [
 *     { block: BlockMobileNav }
 *   ]
 * }
 *
 * @example
 * // Render on medium to large screens only
 * {
 *   block: ViewportCondition,
 *   args: { min: "md", max: "xl" },
 *   children: [
 *     { block: BlockTabletLayout }
 *   ]
 * }
 *
 * @example
 * // Render only on mobile devices
 * {
 *   block: ViewportCondition,
 *   args: { mobile: true },
 *   children: [
 *     { block: BlockMobileAppBanner }
 *   ]
 * }
 *
 * @example
 * // Render only on touch devices
 * {
 *   block: ViewportCondition,
 *   args: { touch: true },
 *   children: [
 *     { block: BlockTouchGestures }
 *   ]
 * }
 */
@block("viewport-condition", { container: true })
export default class ViewportCondition extends Component {
  @service capabilities;

  constructor() {
    super(...arguments);
    this.#validateArgs();
  }

  get shouldRender() {
    const { min, max, mobile, touch } = this.args;

    // Check mobile device
    if (mobile !== undefined) {
      if (mobile && !this.capabilities.isMobileDevice) {
        return false;
      }
      if (!mobile && this.capabilities.isMobileDevice) {
        return false;
      }
    }

    // Check touch capability
    if (touch !== undefined) {
      if (touch && !this.capabilities.touch) {
        return false;
      }
      if (!touch && this.capabilities.touch) {
        return false;
      }
    }

    // Check minimum breakpoint (viewport must be at least this size)
    if (min && !this.capabilities.viewport[min]) {
      return false;
    }

    // Check maximum breakpoint (viewport must be at most this size)
    // For max, we check that the NEXT breakpoint is NOT matched
    if (max) {
      const maxIndex = BREAKPOINTS.indexOf(max);
      const nextBreakpoint = BREAKPOINTS[maxIndex + 1];

      // If there's a larger breakpoint and it matches, we're too big
      if (nextBreakpoint && this.capabilities.viewport[nextBreakpoint]) {
        return false;
      }
    }

    return true;
  }

  #validateArgs() {
    const { min, max } = this.args;

    if (min && !BREAKPOINTS.includes(min)) {
      this.#reportError(
        `ViewportCondition: Invalid \`min\` breakpoint "${min}". ` +
          `Valid breakpoints are: ${BREAKPOINTS.join(", ")}.`
      );
    }

    if (max && !BREAKPOINTS.includes(max)) {
      this.#reportError(
        `ViewportCondition: Invalid \`max\` breakpoint "${max}". ` +
          `Valid breakpoints are: ${BREAKPOINTS.join(", ")}.`
      );
    }

    if (min && max) {
      const minIndex = BREAKPOINTS.indexOf(min);
      const maxIndex = BREAKPOINTS.indexOf(max);

      if (minIndex > maxIndex) {
        this.#reportError(
          `ViewportCondition: \`min\` breakpoint "${min}" is larger than ` +
            `\`max\` breakpoint "${max}". No viewport can satisfy this condition.`
        );
      }
    }
  }

  #reportError(message) {
    if (DEBUG) {
      throw new Error(message);
    } else {
      // eslint-disable-next-line no-console
      console.warn(message);
    }
  }

  <template>
    {{#if this.shouldRender}}
      {{#each this.children as |child|}}
        <child.Component @outletName={{@outletName}} />
      {{/each}}
    {{/if}}
  </template>
}
