// @ts-check
import { getByPath } from "discourse/lib/blocks/utils";

/**
 * Regex for validating source path format: `@outletArgs.propertyName` or
 * `@outletArgs.nested.path`.
 */
const OUTLET_ARGS_SOURCE_PATTERN = /^@outletArgs\.[\w.]+$/;

/**
 * Base class for all block conditions.
 *
 * Subclasses must:
 * - Define a static `type` property (unique string identifier)
 * - Implement the `evaluate(args)` method
 * - Optionally implement the `validate(args)` method for registration-time validation
 * - Optionally define a static `sourceType` property to enable `source` parameter support
 *
 * Condition classes can inject services using `@service` decorator.
 * The BlockConditionEvaluator service sets the owner on condition instances,
 * enabling dependency injection.
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
 * import { BlockCondition } from "discourse/blocks/conditions";
 *
 * export default class BlockMyCondition extends BlockCondition {
 *   static type = "my-condition";
 *   static sourceType = "outletArgs"; // Enable source parameter
 *
 *   @service myService;
 *
 *   validate(args) {
 *     if (!args.requiredArg) {
 *       return { message: "requiredArg is required" };
 *     }
 *     return null;  // No error
 *   }
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
   * @type {string}
   */
  static type;

  /**
   * Declares how this condition handles the `source` parameter.
   *
   * - `"none"` (default): `source` parameter is disallowed
   * - `"outletArgs"`: `source` must be `@outletArgs.property`; base class resolves it
   * - `"object"`: `source` is passed directly as an object (e.g., settings object)
   *
   * @type {"none" | "outletArgs" | "object"}
   */
  static sourceType = "none";

  /**
   * Valid argument keys for this condition.
   *
   * This property is defined by the `@blockCondition` decorator and should not
   * be overridden directly. The decorator creates a non-configurable getter
   * that returns a frozen array.
   *
   * The `source` key is automatically added by the decorator when
   * `sourceType !== "none"`.
   *
   * @type {readonly string[]}
   */
  static validArgKeys;

  /**
   * Validates condition arguments at block registration time.
   * Override this method to check for required args, conflicting args,
   * or invalid values.
   *
   * Returns error info if validation fails, or `null` if validation passes.
   * Subclasses should call `super.validate(args)` first and return early if
   * it returns an error.
   *
   * @param {Object} args - The condition arguments from the layout entry.
   * @returns {{ message: string, path?: string } | null} Error info or null if valid.
   */
  validate(args) {
    // Validate source parameter based on sourceType
    return this.validateSource(args);
  }

  /**
   * Validates the `source` parameter based on the condition's `sourceType`.
   *
   * - `sourceType: "none"`: Returns error if `source` is provided
   * - `sourceType: "outletArgs"`: Validates format is `@outletArgs.propertyPath`
   * - `sourceType: "object"`: Validates `source` is an object if provided
   *
   * @param {Object} args - The condition arguments from the layout entry.
   * @returns {{ message: string, path?: string } | null} Error info or null if valid.
   */
  validateSource(args) {
    const { source } = args;
    // @ts-ignore - Static property defined on subclasses
    const sourceType = this.constructor.sourceType;

    if (source === undefined) {
      return null; // source is always optional
    }

    switch (sourceType) {
      case "none":
        return {
          message: `\`source\` parameter is not supported for this condition type.`,
          path: "source",
        };

      case "outletArgs":
        if (typeof source !== "string") {
          return {
            message: `\`source\` must be a string in format "@outletArgs.propertyName".`,
            path: "source",
          };
        }
        if (!OUTLET_ARGS_SOURCE_PATTERN.test(source)) {
          return {
            message: `\`source\` must be in format "@outletArgs.propertyName", got "${source}".`,
            path: "source",
          };
        }
        break;

      case "object":
        if (source !== null && typeof source !== "object") {
          return {
            message: `\`source\` must be an object.`,
            path: "source",
          };
        }
        break;
    }

    return null;
  }

  /**
   * Resolves the `source` parameter value for conditions with `sourceType: "outletArgs"`.
   *
   * Extracts the property path from `@outletArgs.path.to.value` and retrieves
   * the corresponding value from `context.outletArgs`.
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
