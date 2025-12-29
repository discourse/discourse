import { service } from "@ember/service";
import { BlockCondition, raiseBlockValidationError } from "./base";

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
export default class BlockViewportCondition extends BlockCondition {
  static type = "viewport";

  @service capabilities;

  validate(args) {
    const { min, max } = args;

    if (min && !BREAKPOINTS.includes(min)) {
      raiseBlockValidationError(
        `BlockViewportCondition: Invalid \`min\` breakpoint "${min}". ` +
          `Valid breakpoints are: ${BREAKPOINTS.join(", ")}.`
      );
    }

    if (max && !BREAKPOINTS.includes(max)) {
      raiseBlockValidationError(
        `BlockViewportCondition: Invalid \`max\` breakpoint "${max}". ` +
          `Valid breakpoints are: ${BREAKPOINTS.join(", ")}.`
      );
    }

    if (min && max) {
      const minIndex = BREAKPOINTS.indexOf(min);
      const maxIndex = BREAKPOINTS.indexOf(max);

      if (minIndex > maxIndex) {
        raiseBlockValidationError(
          `BlockViewportCondition: \`min\` breakpoint "${min}" is larger than ` +
            `\`max\` breakpoint "${max}". No viewport can satisfy this condition.`
        );
      }
    }
  }

  evaluate(args) {
    const { min, max, mobile, touch } = args;

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
}
