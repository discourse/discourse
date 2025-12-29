import { DEBUG } from "@glimmer/env";
import { getOwner, setOwner } from "@ember/owner";
import Service from "@ember/service";
import * as conditions from "discourse/blocks/conditions";

/**
 * Raises a validation error in dev/test, logs warning in production.
 *
 * @param {string} message - The error message
 */
function raiseValidationError(message) {
  if (DEBUG) {
    throw new Error(message);
  } else {
    // eslint-disable-next-line no-console
    console.warn(`[Block validation] ${message}`);
  }
}

/**
 * Service that evaluates block conditions.
 *
 * Discovers and registers built-in condition classes automatically via `import *`.
 * Plugins can register custom condition types via `registerType()`.
 *
 * Supports boolean combinators:
 * - Array of conditions: AND logic (all must pass)
 * - `{ any: [...] }`: OR logic (at least one must pass)
 * - `{ not: {...} }`: NOT logic (must fail)
 *
 * @class BlockConditionEvaluator
 * @extends Service
 */
export default class BlockConditionEvaluator extends Service {
  /**
   * Map of condition type names to their instances.
   *
   * @type {Map<string, import("discourse/blocks/conditions").BlockCondition>}
   */
  #types = new Map();

  constructor() {
    super(...arguments);
    this.#discoverBuiltInConditions();
  }

  /**
   * Auto-discover and register built-in condition classes.
   * Iterates over exports from the conditions module and registers
   * any class that extends BlockCondition.
   */
  #discoverBuiltInConditions() {
    for (const exported of Object.values(conditions)) {
      if (
        typeof exported === "function" &&
        exported.prototype instanceof conditions.BlockCondition &&
        exported !== conditions.BlockCondition
      ) {
        this.#registerType(exported);
      }
    }
  }

  /**
   * Internal registration method.
   * Validates the condition class and creates an instance with owner set.
   *
   * @param {typeof import("discourse/blocks/conditions").BlockCondition} ConditionClass
   */
  #registerType(ConditionClass) {
    if (!(ConditionClass.prototype instanceof conditions.BlockCondition)) {
      raiseValidationError(`${ConditionClass.name} must extend BlockCondition`);
      return;
    }

    if (!ConditionClass.type || typeof ConditionClass.type !== "string") {
      raiseValidationError(
        `${ConditionClass.name} must define a static 'type' property`
      );
      return;
    }

    if (this.#types.has(ConditionClass.type)) {
      raiseValidationError(
        `Condition type "${ConditionClass.type}" is already registered`
      );
      return;
    }

    const instance = new ConditionClass();
    setOwner(instance, getOwner(this));
    this.#types.set(ConditionClass.type, instance);
  }

  /**
   * Register a custom condition type.
   * Used by plugins via `api.registerBlockConditionType()`.
   *
   * @param {typeof import("discourse/blocks/conditions").BlockCondition} ConditionClass
   *
   * @example
   * ```javascript
   * class BlockMyCondition extends BlockCondition {
   *   static type = "my-condition";
   *   evaluate(args) { return true; }
   * }
   * api.registerBlockConditionType(BlockMyCondition);
   * ```
   */
  registerType(ConditionClass) {
    this.#registerType(ConditionClass);
  }

  /**
   * Validates condition specs at block registration time.
   * Recursively validates nested conditions in `any` and `not` combinators.
   *
   * @param {Object|Array<Object>} conditionSpec - Condition spec(s) to validate
   * @throws {Error} If validation fails
   */
  validate(conditionSpec) {
    if (!conditionSpec) {
      return;
    }

    // Array of conditions (AND logic)
    if (Array.isArray(conditionSpec)) {
      for (const condition of conditionSpec) {
        this.validate(condition);
      }
      return;
    }

    // OR combinator
    if (conditionSpec.any !== undefined) {
      if (!Array.isArray(conditionSpec.any)) {
        raiseValidationError(
          'Block condition: "any" must be an array of conditions'
        );
        return;
      }
      for (const condition of conditionSpec.any) {
        this.validate(condition);
      }
      return;
    }

    // NOT combinator
    if (conditionSpec.not !== undefined) {
      if (
        typeof conditionSpec.not !== "object" ||
        Array.isArray(conditionSpec.not)
      ) {
        raiseValidationError(
          'Block condition: "not" must be a single condition object'
        );
        return;
      }
      this.validate(conditionSpec.not);
      return;
    }

    // Single condition with type
    const { type, ...args } = conditionSpec;

    if (!type) {
      raiseValidationError(
        `Block condition is missing "type" property: ${JSON.stringify(conditionSpec)}`
      );
      return;
    }

    const conditionInstance = this.#types.get(type);

    if (!conditionInstance) {
      const availableTypes = [...this.#types.keys()].join(", ");
      raiseValidationError(
        `Unknown block condition type: "${type}". Available types: ${availableTypes}`
      );
      return;
    }

    // Run the condition's own validation
    conditionInstance.validate(args);
  }

  /**
   * Evaluates condition specs at render time.
   * Recursively evaluates nested conditions with AND/OR/NOT logic.
   *
   * @param {Object|Array<Object>} conditionSpec - Condition spec(s) to evaluate
   * @returns {boolean} True if conditions pass, false otherwise
   */
  evaluate(conditionSpec) {
    if (!conditionSpec) {
      return true;
    }

    // Array of conditions (AND logic - all must pass)
    if (Array.isArray(conditionSpec)) {
      return conditionSpec.every((condition) => this.evaluate(condition));
    }

    // OR combinator (at least one must pass)
    if (conditionSpec.any !== undefined) {
      return conditionSpec.any.some((condition) => this.evaluate(condition));
    }

    // NOT combinator (must fail)
    if (conditionSpec.not !== undefined) {
      return !this.evaluate(conditionSpec.not);
    }

    // Single condition with type
    const { type, ...args } = conditionSpec;
    const conditionInstance = this.#types.get(type);

    if (!conditionInstance) {
      // This shouldn't happen if validate() was called first
      // but fail closed (don't render) if it does
      return false;
    }

    return conditionInstance.evaluate(args);
  }

  /**
   * Checks if a condition type is registered.
   *
   * @param {string} type - The condition type name
   * @returns {boolean}
   */
  hasType(type) {
    return this.#types.has(type);
  }

  /**
   * Returns all registered condition type names.
   * Useful for debugging and error messages.
   *
   * @returns {string[]}
   */
  getRegisteredTypes() {
    return [...this.#types.keys()];
  }
}
