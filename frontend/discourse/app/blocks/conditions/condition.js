import { raiseBlockError } from "discourse/lib/blocks/error";
import { getByPath } from "discourse/lib/blocks/path-resolver";

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
 * @class BlockCondition
 *
 * @example
 * ```javascript
 * import { BlockCondition, raiseBlockValidationError } from "discourse/blocks/conditions";
 *
 * export default class BlockMyCondition extends BlockCondition {
 *   static type = "my-condition";
 *   static sourceType = "outletArgs"; // Enable source parameter
 *
 *   @service myService;
 *
 *   validate(args) {
 *     if (!args.requiredArg) {
 *       raiseBlockValidationError("requiredArg is required");
 *     }
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
   * Note: Base class validation for `source` parameter is handled automatically
   * via `validateSource()`. Subclasses should call `super.validate(args)` if
   * they override this method.
   *
   * @param {Object} args - The condition arguments from the block config.
   * @throws {BlockError} If validation fails.
   */

  validate(args) {
    // Validate source parameter based on sourceType
    this.validateSource(args);
  }

  /**
   * Validates the `source` parameter based on the condition's `sourceType`.
   *
   * - `sourceType: "none"`: Throws if `source` is provided
   * - `sourceType: "outletArgs"`: Validates format is `@outletArgs.propertyPath`
   * - `sourceType: "object"`: Validates `source` is an object if provided
   *
   * @param {Object} args - The condition arguments from the block config.
   * @throws {BlockError} If source validation fails.
   */
  validateSource(args) {
    const { source } = args;
    const sourceType = this.constructor.sourceType;

    if (source === undefined) {
      return; // source is always optional
    }

    switch (sourceType) {
      case "none":
        raiseBlockError(
          `${this.constructor.name}: \`source\` parameter is not supported for this condition type.`
        );
        break;

      case "outletArgs":
        if (typeof source !== "string") {
          raiseBlockError(
            `${this.constructor.name}: \`source\` must be a string in format "@outletArgs.propertyName".`
          );
        }
        if (!OUTLET_ARGS_SOURCE_PATTERN.test(source)) {
          raiseBlockError(
            `${this.constructor.name}: \`source\` must be in format "@outletArgs.propertyName", ` +
              `got "${source}".`
          );
        }
        break;

      case "object":
        if (source !== null && typeof source !== "object") {
          raiseBlockError(
            `${this.constructor.name}: \`source\` must be an object.`
          );
        }
        break;
    }
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
   * @param {Object} args - The condition arguments from the block config.
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
   * @param {Object} args - The condition arguments from the block config.
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

/**
 * Raises a block validation error.
 *
 * In development/test environments, throws a `BlockError`.
 * In production, dispatches a `discourse-error` event that surfaces the error
 * to admin users via a banner (handled by `ClientErrorHandlerService`).
 *
 * @param {string} message - The error message describing the validation failure.
 * @throws {BlockError} In development/test environments.
 */
export function raiseBlockValidationError(message) {
  raiseBlockError(message);
}
