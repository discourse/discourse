import { raiseBlockError } from "discourse/lib/blocks/error";

/**
 * Base class for all block conditions.
 *
 * Subclasses must:
 * - Define a static `type` property (unique string identifier)
 * - Implement the `evaluate(args)` method
 * - Optionally implement the `validate(args)` method for registration-time validation
 *
 * Condition classes can inject services using `@service` decorator.
 * The BlockConditionEvaluator service sets the owner on condition instances,
 * enabling dependency injection.
 *
 * @class BlockCondition
 *
 * @example
 * ```javascript
 * import { BlockCondition, raiseBlockValidationError } from "discourse/blocks/conditions";
 *
 * export default class BlockMyCondition extends BlockCondition {
 *   static type = "my-condition";
 *
 *   @service myService;
 *
 *   validate(args) {
 *     if (!args.requiredArg) {
 *       raiseBlockValidationError("requiredArg is required");
 *     }
 *   }
 *
 *   evaluate(args) {
 *     return this.myService.someCheck(args.requiredArg);
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
   * Validates condition arguments at block registration time.
   * Override this method to check for required args, conflicting args,
   * or invalid values.
   *
   * @param {Object} args - The condition arguments from the block config.
   * @throws {BlockError} If validation fails.
   */
  // eslint-disable-next-line no-unused-vars
  validate(args) {
    // Default implementation: no validation
    // Subclasses should override to add validation logic
  }

  /**
   * Evaluates whether the condition passes.
   * Called at render time to determine if a block should be shown.
   *
   * @param {Object} args - The condition arguments from the block config.
   * @param {Object} [context] - Evaluation context from the blocks service.
   * @param {boolean} [context.debug] - Whether debug logging is enabled.
   * @param {number} [context._depth] - Current nesting depth for logging.
   * @returns {boolean} True if condition passes, false otherwise.
   */
  // eslint-disable-next-line no-unused-vars
  evaluate(args, context) {
    throw new Error(`${this.constructor.name} must implement evaluate()`);
  }
}

/**
 * Raises a block validation error.
 *
 * In development/test environments, throws a `BlockError`.
 * In production, dispatches a `discourse-error` event that surfaces the error
 * to admin users via a banner (handled by `ClientErrorHandlerService`).
 *
 * If an error context has been set via `setBlockErrorContext()`, the error
 * message will include the block hierarchy and conditions config for debugging.
 *
 * @param {string} message - The error message describing the validation failure.
 * @throws {BlockError} In development/test environments.
 */
export function raiseBlockValidationError(message) {
  raiseBlockError(message);
}
