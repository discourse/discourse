// @ts-check
import { getByPath } from "discourse/lib/blocks/utils";

/**
 * Base class for all block conditions.
 *
 * Subclasses must:
 * - Use the `@blockCondition` decorator with `type` and `args` schema config
 * - Implement the `evaluate(args, context)` method
 * - Optionally provide a `validate` function in the decorator config for custom validation
 * - Optionally pass `sourceType` to the decorator to enable `source` parameter support
 *
 * Condition classes can inject services using `@service` decorator.
 * The Blocks service sets the owner on condition instances, enabling dependency injection.
 *
 * ## Validation Flow
 *
 * Validation happens at block registration time in this order:
 * 1. Unknown args are detected (typo detection with suggestions)
 * 2. Arg values are validated against the `args` schema (type, min, max, pattern, etc.)
 * 3. Constraints are validated (atLeastOne, exactlyOne, allOrNone, atMostOne)
 * 4. Source parameter is validated (based on sourceType)
 * 5. Custom `validate` function from decorator config is called (if provided)
 *
 * ## Source Parameter Support
 *
 * Conditions can declare support for the `source` parameter via `static sourceType`:
 *
 * - `"none"` (default): `source` parameter is disallowed
 * - `"outletArgs"`: `source` must be `@outletArgs.propertyPath`; base class resolves it
 * - `"object"`: `source` is passed directly as an object (e.g., for settings)
 *
 * When `sourceType` is `"outletArgs"`, use `resolveSource(args, context)` to get the
 * resolved value from outlet args.
 *
 * @experimental This API is under active development and may change or be removed
 * in future releases without prior notice. Use with caution in production environments.
 *
 * @class BlockCondition
 *
 * @example
 * ```javascript
 * import { blockCondition, BlockCondition } from "discourse/blocks/conditions";
 *
 * @blockCondition({
 *   type: "my-condition",
 *   sourceType: "outletArgs",
 *   args: {
 *     requiredArg: { type: "string", required: true },
 *     optionalCount: { type: "number", min: 0, max: 10 },
 *   },
 *   validate(args) {
 *     // Custom validation that can't be expressed in schema
 *     if (args.requiredArg === "forbidden") {
 *       return "requiredArg cannot be 'forbidden'";
 *     }
 *     return null;
 *   }
 * })
 * export default class BlockMyCondition extends BlockCondition {
 *   @service myService;
 *
 *   evaluate(args, context) {
 *     // Get value from source (outlet args) or fall back to service
 *     const value = this.resolveSource(args, context) ?? this.myService.defaultValue;
 *     return this.myService.someCheck(value, args.requiredArg);
 *   }
 * }
 * ```
 */
export class BlockCondition {
  /**
   * Unique identifier for this condition type.
   * Used in condition specs: `{ type: "route", ... }`
   *
   * This property is defined by the `@blockCondition` decorator and should not
   * be set directly. Pass the `type` option to the decorator instead.
   *
   * @type {string}
   */
  static type;

  /**
   * Declares how this condition handles the `source` parameter.
   *
   * - `"none"` (default): `source` parameter is disallowed
   * - `"outletArgs"`: `source` must be `@outletArgs.propertyPath`; base class resolves it
   * - `"object"`: `source` is passed directly as an object (e.g., settings object)
   *
   * This property is defined by the `@blockCondition` decorator and should not
   * be set directly. Pass the `sourceType` option to the decorator instead.
   *
   * @type {"none" | "outletArgs" | "object"}
   */
  static sourceType = "none";

  /**
   * Arg schema definitions for this condition.
   *
   * This property is defined by the `@blockCondition` decorator and should not
   * be overridden directly. The decorator creates a non-configurable getter
   * that returns a frozen object.
   *
   * @type {Object}
   */
  static argsSchema;

  /**
   * Cross-arg constraint definitions for this condition.
   *
   * This property is defined by the `@blockCondition` decorator and should not
   * be overridden directly. The decorator creates a non-configurable getter
   * that returns a frozen object or undefined.
   *
   * @type {Object|undefined}
   */
  static constraints;

  /**
   * Custom validation function for this condition.
   *
   * This property is defined by the `@blockCondition` decorator and should not
   * be overridden directly. The decorator creates a non-configurable getter
   * that returns the validate function or undefined.
   *
   * @type {Function|undefined}
   */
  static validateFn;

  /**
   * Valid argument keys for this condition.
   *
   * This property is derived from the `args` schema by the `@blockCondition`
   * decorator and should not be overridden directly.
   *
   * The `source` key is automatically added by the decorator when
   * `sourceType !== "none"`.
   *
   * @type {readonly string[]}
   */
  static validArgKeys;

  /**
   * Resolves the `source` parameter value based on the condition's `sourceType`.
   *
   * - `sourceType: "outletArgs"`: Extracts the property path from `@outletArgs.path.to.value`
   *   and retrieves the corresponding value from `context.outletArgs`.
   * - `sourceType: "object"`: Returns the `source` value directly.
   *
   * @param {Object} args - The condition arguments containing `source`.
   * @param {Object} context - Evaluation context containing `outletArgs`.
   * @param {Object} [context.outletArgs] - The outlet args passed to the block.
   * @returns {*} The resolved value from outlet args, or undefined if not found.
   */
  resolveSource(args, context) {
    const { source } = args;

    if (!source) {
      return undefined;
    }

    // @ts-ignore - Static property defined on subclasses
    const sourceType = this.constructor.sourceType;

    if (sourceType === "object") {
      return source;
    }

    if (sourceType === "outletArgs") {
      // Extract path after "@outletArgs."
      const path = source.replace(/^@outletArgs\./, "");
      return getByPath(context?.outletArgs, path);
    }

    return undefined;
  }

  /**
   * Default source value when `source` parameter is not provided.
   * Override in subclasses to provide a fallback (e.g., currentUser, siteSettings).
   *
   * @type {*}
   */
  get defaultSource() {
    return undefined;
  }

  /**
   * Resolves the source value, falling back to defaultSource when not provided.
   *
   * @param {Object} args - The condition arguments.
   * @param {Object} [context] - Evaluation context.
   * @returns {*} The resolved source or defaultSource.
   */
  getSourceValue(args, context) {
    return args.source !== undefined
      ? this.resolveSource(args, context)
      : this.defaultSource;
  }

  /**
   * Evaluates whether the condition passes.
   * Called at render time to determine if a block should be shown.
   *
   * **Note: This method MUST be pure and idempotent.** It may be called
   * multiple times during a single render cycle (e.g., when debug logging
   * is enabled), and should not have side effects.
   *
   * @param {Object} args - The condition arguments from the layout entry.
   * @param {Object} [context] - Evaluation context from the blocks service.
   * @param {boolean} [context.debug] - Whether debug logging is enabled.
   * @param {Object} [context.outletArgs] - Outlet args for source resolution.
   * @param {number} [context._depth] - Current nesting depth for logging.
   * @returns {boolean} True if condition passes, false otherwise.
   */
  // eslint-disable-next-line no-unused-vars
  evaluate(args, context) {
    throw new Error(`${this.constructor.name} must implement evaluate()`);
  }

  /**
   * Returns the resolved value for debug logging purposes.
   *
   * Override this method in subclasses to provide custom resolved values
   * for conditions that don't use the standard `source` parameter.
   * For example, the `outletArg` condition uses a `path` parameter
   * to resolve values from outlet args.
   *
   * @param {Object} args - The condition arguments from the layout entry.
   * @param {Object} [context] - Evaluation context containing outletArgs.
   * @returns {{ value: *, hasValue: true }|undefined} Object with resolved value,
   *   or undefined if this condition doesn't resolve values.
   */
  getResolvedValueForLogging(args, context) {
    // Default implementation returns resolved source if present
    if (args.source !== undefined) {
      return { value: this.resolveSource(args, context), hasValue: true };
    }
    return undefined;
  }
}
