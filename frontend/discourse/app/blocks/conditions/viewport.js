// @ts-check
import { service } from "@ember/service";
import { BlockCondition } from "./condition";
import { blockCondition } from "./decorator";

/**
 * Available viewport breakpoint names.
 * Values match the breakpoints defined in capabilities.viewport.
 *
 * @constant {ReadonlyArray<string>}
 */
const BREAKPOINTS = Object.freeze(["sm", "md", "lg", "xl", "2xl"]);

/**
 * A condition that evaluates based on viewport size and device capabilities.
 *
 * Uses the standard Discourse breakpoints from the capabilities service:
 * - sm: >= 40rem (640px)
 * - md: >= 48rem (768px)
 * - lg: >= 64rem (1024px)
 * - xl: >= 80rem (1280px)
 * - 2xl: >= 96rem (1536px)
 *
 * **Note:** For simple show/hide based on viewport, CSS media queries are often
 * more performant. Use this condition when you need to completely remove components
 * from the DOM on certain viewports, or when the block content differs significantly
 * between viewports.
 *
 * @class BlockViewportCondition
 * @extends BlockCondition
 *
 * @param {string} [min] - Minimum breakpoint required (passes at this size and larger)
 * @param {string} [max] - Maximum breakpoint allowed (passes at this size and smaller)
 * @param {boolean} [mobile] - If true, passes only on mobile devices; if false, only on non-mobile
 * @param {boolean} [touch] - If true, passes only on touch devices; if false, only on non-touch
 *
 * @example
 * // Large screens only (lg and up)
 * { type: "viewport", min: "lg" }
 *
 * @example
 * // Small screens only (below md)
 * { type: "viewport", max: "sm" }
 *
 * @example
 * // Medium to large screens only
 * { type: "viewport", min: "md", max: "xl" }
 *
 * @example
 * // Mobile devices only
 * { type: "viewport", mobile: true }
 *
 * @example
 * // Touch devices only
 * { type: "viewport", touch: true }
 */
@blockCondition({
  type: "viewport",
  args: {
    min: { type: "string", enum: BREAKPOINTS },
    max: { type: "string", enum: BREAKPOINTS },
    mobile: { type: "boolean" },
    touch: { type: "boolean" },
  },
  constraints: {
    atLeastOne: ["min", "max", "mobile", "touch"],
  },
  validate(args) {
    const { min, max } = args;

    // Check that min <= max when both are specified
    if (min && max) {
      const minIndex = BREAKPOINTS.indexOf(min);
      const maxIndex = BREAKPOINTS.indexOf(max);

      if (minIndex > maxIndex) {
        return (
          `\`min\` breakpoint "${min}" is larger than ` +
          `\`max\` breakpoint "${max}". No viewport can satisfy this condition.`
        );
      }
    }

    return null;
  },
})
export default class BlockViewportCondition extends BlockCondition {
  @service capabilities;

  /**
   * Evaluates whether the viewport condition passes.
   *
   * @param {Object} args - The condition arguments.
   * @returns {boolean} True if the condition passes.
   */
  evaluate(args) {
    const { min, max, mobile, touch } = args;

    // Check mobile device
    if (mobile !== undefined && mobile !== this.capabilities.isMobileDevice) {
      return false;
    }

    // Check touch capability
    if (touch !== undefined && touch !== this.capabilities.touch) {
      return false;
    }

    // Check minimum breakpoint (viewport must be at least this size)
    if (min && !this.capabilities.viewport[min]) {
      return false;
    }

    // Check maximum breakpoint (viewport must be at most this size).
    // For max, we check that the NEXT breakpoint is NOT matched. This works
    // because BREAKPOINTS is ordered from smallest to largest (sm < md < lg...),
    // and capabilities.viewport[breakpoint] returns true if the viewport is AT
    // LEAST that size. So if the next larger breakpoint matches, we're too big.
    if (max) {
      const maxIndex = BREAKPOINTS.indexOf(max);
      const nextBreakpoint = BREAKPOINTS[maxIndex + 1];

      if (nextBreakpoint && this.capabilities.viewport[nextBreakpoint]) {
        return false;
      }
    }

    return true;
  }
}
