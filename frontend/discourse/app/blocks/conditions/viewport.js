// @ts-check
import { service } from "@ember/service";
import { formatWithSuggestion } from "discourse/lib/string-similarity";
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
  validArgKeys: ["min", "max", "mobile", "touch"],
})
export default class BlockViewportCondition extends BlockCondition {
  @service capabilities;

  /**
   * Validates viewport condition arguments at block registration time.
   *
   * Checks that min/max breakpoints are valid values from the BREAKPOINTS array
   * and that min is not larger than max when both are specified.
   *
   * @param {Object} args - The condition arguments.
   * @param {string} [args.min] - Minimum breakpoint (viewport must be at least this size).
   * @param {string} [args.max] - Maximum breakpoint (viewport must be at most this size).
   * @param {boolean} [args.touch] - Whether to check for touch capability.
   * @throws {BlockError} If validation fails.
   */
  validate(args) {
    // Check base class validation (source parameter)
    const baseError = super.validate(args);
    if (baseError) {
      return baseError;
    }

    const { min, max } = args;

    if (min && !BREAKPOINTS.includes(min)) {
      const suggestion = formatWithSuggestion(min, BREAKPOINTS);
      return {
        message:
          `Invalid \`min\` breakpoint ${suggestion}. ` +
          `Valid breakpoints are: ${BREAKPOINTS.join(", ")}.`,
        path: "min",
      };
    }

    if (max && !BREAKPOINTS.includes(max)) {
      const suggestion = formatWithSuggestion(max, BREAKPOINTS);
      return {
        message:
          `Invalid \`max\` breakpoint ${suggestion}. ` +
          `Valid breakpoints are: ${BREAKPOINTS.join(", ")}.`,
        path: "max",
      };
    }

    if (min && max) {
      const minIndex = BREAKPOINTS.indexOf(min);
      const maxIndex = BREAKPOINTS.indexOf(max);

      if (minIndex > maxIndex) {
        return {
          message:
            `\`min\` breakpoint "${min}" is larger than ` +
            `\`max\` breakpoint "${max}". No viewport can satisfy this condition.`,
        };
      }
    }

    return null;
  }

  /**
   * Evaluates whether the viewport condition passes.
   *
   * @param {Object} args - The condition arguments.
   * @returns {boolean} True if the condition passes.
   */
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
