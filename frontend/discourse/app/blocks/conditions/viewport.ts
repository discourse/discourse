import { service } from "@ember/service";
import { BlockCondition } from "./condition";
import { blockCondition } from "./decorator";

/** A viewport breakpoint name, matching the breakpoints defined in
 *  `capabilities.viewport`. */
type Breakpoint = "sm" | "md" | "lg" | "xl" | "2xl";

/** Args accepted by the `viewport` condition. */
interface ViewportConditionArgs {
  /** Minimum breakpoint required (passes at this size and larger). */
  min?: Breakpoint;

  /** Maximum breakpoint allowed (passes at this size and smaller). */
  max?: Breakpoint;

  /** If true, passes only on touch devices; if false, only on non-touch. */
  touch?: boolean;
}

/**
 * Available viewport breakpoint names.
 * Values match the breakpoints defined in capabilities.viewport.
 */
const BREAKPOINTS: readonly Breakpoint[] = Object.freeze([
  "sm",
  "md",
  "lg",
  "xl",
  "2xl",
]);

/**
 * A condition that evaluates based on viewport size and device capabilities.
 *
 * Uses the standard Discourse breakpoints from the capabilities service:
 * - sm: \>= 40rem (640px)
 * - md: \>= 48rem (768px)
 * - lg: \>= 64rem (1024px)
 * - xl: \>= 80rem (1280px)
 * - 2xl: \>= 96rem (1536px)
 *
 * **Note:** For simple show/hide based on viewport, CSS media queries are often
 * more performant. Use this condition when you need to completely remove components
 * from the DOM on certain viewports, or when the block content differs significantly
 * between viewports.
 *
 * @example
 * ```
 * // Large screens only (lg and up)
 * { type: "viewport", min: "lg" }
 * ```
 *
 * @example
 * ```
 * // Small screens only (below md)
 * { type: "viewport", max: "sm" }
 * ```
 *
 * @example
 * ```
 * // Medium to large screens only
 * { type: "viewport", min: "md", max: "xl" }
 * ```
 *
 * @example
 * ```
 * // Touch devices only
 * { type: "viewport", touch: true }
 * ```
 */
@blockCondition({
  type: "viewport",
  args: {
    // `enum` widens to a mutable `unknown[]`; BREAKPOINTS stays a frozen,
    // precisely-typed `readonly Breakpoint[]` for use elsewhere in this file.
    min: { type: "string", enum: BREAKPOINTS as unknown[] },
    max: { type: "string", enum: BREAKPOINTS as unknown[] },
    touch: { type: "boolean" },
  },
  constraints: {
    atLeastOne: ["min", "max", "touch"],
  },
  validate(args) {
    const { min, max } = args as ViewportConditionArgs;

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
  @service
  declare capabilities: import("discourse/services/capabilities").Capabilities;

  /**
   * Evaluates whether the viewport condition passes.
   */
  evaluate(args: Record<string, unknown>): boolean {
    const { min, max, touch } = args as ViewportConditionArgs;

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
