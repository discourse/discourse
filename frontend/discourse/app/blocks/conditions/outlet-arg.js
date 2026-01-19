// @ts-check
import { getByPath } from "discourse/lib/blocks/utils";
import { matchValue } from "discourse/lib/blocks/value-matcher";
import { BlockCondition } from "./condition";
import { blockCondition } from "./decorator";

/**
 * A condition that evaluates based on outlet arg values.
 *
 * Checks properties passed via `@outletArgs` on the BlockOutlet. Supports
 * dot-notation paths for nested properties and flexible value matching.
 *
 * @class BlockOutletArgCondition
 * @extends BlockCondition
 *
 * @param {string} path - Dot-notation path to the property (required).
 *   E.g., `"topic.closed"`, `"user.trust_level"`, `"category.id"`.
 * @param {*} [value] - Value to match against (see matching rules below).
 * @param {boolean} [exists] - If true, passes when property exists (not undefined);
 *   if false, passes when property is undefined.
 *
 * ## Value Matching Rules
 *
 * When `value` is omitted, passes if the property is truthy.
 *
 * When `value` is provided, uses the shared `matchValue` utility:
 *
 * - **Primitive**: Passes if `actual === value` (strict equality)
 * - **RegExp**: Passes if `actual` (coerced to string) matches the pattern
 * - **[...values]**: Passes if `actual` matches ANY element (OR logic)
 * - **`{ not: value }`**: Passes if `actual` does NOT match `value`
 * - **`{ any: [...] }`**: Passes if `actual` matches ANY spec in array (OR logic)
 *
 * @example
 * // Check if topic is closed
 * { type: "outletArg", path: "topic.closed", value: true }
 *
 * @example
 * // Check user trust level is 2 or higher
 * { type: "outletArg", path: "user.trust_level", value: [2, 3, 4] }
 *
 * @example
 * // Check category is one of several IDs
 * { type: "outletArg", path: "category.id", value: [1, 2, 3] }
 *
 * @example
 * // Check if topic property exists
 * { type: "outletArg", path: "topic", exists: true }
 *
 * @example
 * // Check topic is NOT closed
 * { type: "outletArg", path: "topic.closed", value: { not: true } }
 *
 * @example
 * // Check category slug matches pattern
 * { type: "outletArg", path: "category.slug", value: /^support/ }
 *
 * @example
 * // Check topic is closed OR archived (using any)
 * { type: "outletArg", path: "topic.closed", value: { any: [true, { not: false }] } }
 */
@blockCondition({
  type: "outletArg",
  validArgKeys: ["path", "value", "exists"],
})
export default class BlockOutletArgCondition extends BlockCondition {
  validate(args) {
    // Check base class validation (source parameter)
    const baseError = super.validate(args);
    if (baseError) {
      return baseError;
    }

    const { path: argPath, value, exists } = args;

    if (!argPath) {
      return {
        message: "`path` argument is required.",
        path: "path",
      };
    }

    if (typeof argPath !== "string") {
      return {
        message: "`path` must be a string.",
        path: "path",
      };
    }

    // Validate path format (alphanumeric, underscores, dots)
    if (!/^[\w.]+$/.test(argPath)) {
      return {
        message:
          `\`path\` "${argPath}" is invalid. ` +
          `Use dot-notation with alphanumeric characters (e.g., "user.trust_level").`,
        path: "path",
      };
    }

    // Validate parameter types
    const typeError = this.validateTypes(args, { exists: "boolean" });
    if (typeError) {
      return typeError;
    }

    // Check for conflicting conditions
    if (value !== undefined && exists !== undefined) {
      return {
        message: "Cannot use both `value` and `exists` together.",
      };
    }

    return null;
  }

  evaluate(args, context) {
    const { path, value, exists } = args;
    const outletArgs = context?.outletArgs;

    // Get the value at the path
    const targetValue = getByPath(outletArgs, path);

    // Check existence if specified
    if (exists !== undefined) {
      const doesExist = targetValue !== undefined;
      return exists ? doesExist : !doesExist;
    }

    // When no value is specified, check truthiness
    if (value === undefined) {
      return !!targetValue;
    }

    // Use shared value matching with named parameters
    return matchValue({
      actual: targetValue,
      expected: value,
      paramName: path,
    });
  }

  /**
   * Returns the resolved value at the path for debug logging.
   *
   * @param {Object} args - The condition arguments containing `path`, `value`, `exists`.
   * @param {Object} [context] - Evaluation context containing outletArgs.
   * @returns {{
   *   hasValue: true,
   *   formatted: {
   *     path: string,
   *     actual: *,
   *     configured: * | { exists: boolean }
   *   }
   * }} Object with formatted log data showing path, actual value, and configured expectation.
   */
  // @ts-ignore - TS2416: Override returns formatted object instead of base class value structure
  getResolvedValueForLogging(args, context) {
    const { path, value, exists } = args;
    return {
      hasValue: true,
      formatted: {
        path,
        actual: getByPath(context?.outletArgs, path),
        configured: exists !== undefined ? { exists } : value,
      },
    };
  }
}
