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
 * // Touch devices only
 * { type: "viewport", touch: true }
 */
@blockCondition({
  type: "viewport",
  displayName: "Viewport",
  description: "Match by screen-size breakpoint or touch capability.",
  args: {
    min: { type: "string", enum: BREAKPOINTS },
    max: { type: "string", enum: BREAKPOINTS },
    touch: { type: "boolean" },
  },
  constraints: {
    atLeastOne: ["min", "max", "touch"],
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
   * Returns the boolean source object the condition checks against. By
   * default this is the live `capabilities` service (so its
   * `capabilities.viewport.{sm|md|lg|xl|2xl}` getters and `capabilities.touch`
   * are read on every evaluation), but when the visual editor's persona
   * toolbar sets `context.simulation.viewport`, the simulated shape replaces
   * the service entirely.
   *
   * The simulated payload is expected to expose the same surface
   * (`{ viewport: {<breakpoint>: boolean, ...}, touch: boolean }`); we
   * recommend deriving it from a single breakpoint pick via
   * `buildSimulatedViewport()` below so the matrix stays self-consistent.
   *
   * @param {Object} [context] - Evaluation context.
   * @returns {{viewport: Object, touch: boolean}}
   */
  capabilitiesSource(context) {
    // Use `in` so an explicit `null` viewport (a sim slot the author may
    // set to mean "fall back to real, but persona is still simulated")
    // still falls back here cleanly.
    if (context?.simulation && "viewport" in context.simulation) {
      const sim = context.simulation.viewport;
      if (sim) {
        return sim;
      }
    }
    return this.capabilities;
  }

  /**
   * Evaluates whether the viewport condition passes.
   *
   * @param {Object} args - The condition arguments.
   * @param {Object} [context] - Evaluation context.
   * @returns {boolean} True if the condition passes.
   */
  evaluate(args, context) {
    const { min, max, touch } = args;
    const caps = this.capabilitiesSource(context);

    // Check touch capability
    if (touch !== undefined && touch !== caps.touch) {
      return false;
    }

    // Check minimum breakpoint (viewport must be at least this size)
    if (min && !caps.viewport[min]) {
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

      if (nextBreakpoint && caps.viewport[nextBreakpoint]) {
        return false;
      }
    }

    return true;
  }
}

/**
 * Builds a `{viewport, touch}` payload suitable for
 * `context.simulation.viewport`. Derives the per-breakpoint booleans
 * from a single chosen breakpoint (the "current" simulated size) — every
 * breakpoint at-or-below the chosen size resolves to `true`, every
 * larger one to `false`. Keeps the simulated state self-consistent
 * with the real `capabilities.viewport` semantics (which return `true`
 * when the viewport is AT LEAST that size).
 *
 * @param {{ breakpoint: "sm"|"md"|"lg"|"xl"|"2xl", touch?: boolean }} pick
 * @returns {{ viewport: Object, touch: boolean }}
 */
export function buildSimulatedViewport({ breakpoint, touch = false }) {
  const idx = BREAKPOINTS.indexOf(breakpoint);
  const viewport = {};
  BREAKPOINTS.forEach((bp, i) => {
    viewport[bp] = i <= idx;
  });
  return { viewport, touch };
}
