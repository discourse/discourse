import { DEBUG } from "@glimmer/env";
import { getOwner, setOwner } from "@ember/owner";
import Service from "@ember/service";
import * as coreBlocks from "discourse/blocks";
import * as conditions from "discourse/blocks/conditions";
import { isBlock } from "discourse/components/block-outlet";
import {
  _registerBlock,
  blockRegistry,
} from "discourse/lib/blocks/registration";

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
    console.warn(`[Blocks service] ${message}`);
  }
}

/**
 * Unified service for block registry and condition evaluation.
 *
 * ## Block Registry
 *
 * Provides introspection for registered block components:
 * - `getBlock(name)` - Get a block by name
 * - `hasBlock(name)` - Check if a block is registered
 * - `listBlocks()` - Get all registered blocks
 * - `listBlocksWithMetadata()` - Get all blocks with their metadata
 *
 * Core blocks are auto-discovered from `discourse/blocks`.
 * Theme/plugin blocks are registered via `api.registerBlock()` in pre-initializers.
 *
 * ## Condition Evaluation
 *
 * Evaluates block render conditions at runtime:
 * - `evaluate(conditionSpec)` - Evaluate condition(s)
 * - `validate(conditionSpec)` - Validate condition(s) at registration time
 * - `registerConditionType(ConditionClass)` - Register custom condition types
 *
 * Built-in condition types are auto-discovered from `discourse/blocks/conditions`.
 *
 * Supports boolean combinators:
 * - Array of conditions: AND logic (all must pass)
 * - `{ any: [...] }`: OR logic (at least one must pass)
 * - `{ not: {...} }`: NOT logic (must fail)
 *
 * @class Blocks
 * @extends Service
 */
export default class Blocks extends Service {
  /**
   * Map of condition type names to their instances.
   *
   * @type {Map<string, import("discourse/blocks/conditions").BlockCondition>}
   */
  #conditionTypes = new Map();

  constructor() {
    super(...arguments);
    this.#discoverBuiltInBlocks();
    this.#discoverBuiltInConditions();
  }

  // ============================================================================
  // Block Registry Methods
  // ============================================================================

  /**
   * Auto-discover and register built-in block components.
   * Iterates over exports from the blocks module and registers
   * any class decorated with @block.
   */
  #discoverBuiltInBlocks() {
    for (const exported of Object.values(coreBlocks)) {
      if (typeof exported === "function" && isBlock(exported)) {
        _registerBlock(exported);
      }
    }
  }

  /**
   * Gets a registered block by name.
   *
   * @param {string} name - The block name (e.g., "hero-banner")
   * @returns {typeof import("@glimmer/component").default|undefined} The block class, or undefined if not found
   *
   * @example
   * ```javascript
   * const HeroBanner = this.blocks.getBlock("hero-banner");
   * ```
   */
  getBlock(name) {
    return blockRegistry.get(name);
  }

  /**
   * Checks if a block is registered.
   *
   * @param {string} name - The block name
   * @returns {boolean}
   *
   * @example
   * ```javascript
   * if (this.blocks.hasBlock("hero-banner")) {
   *   // Block is available
   * }
   * ```
   */
  hasBlock(name) {
    return blockRegistry.has(name);
  }

  /**
   * Returns all registered block classes.
   *
   * @returns {Array<typeof import("@glimmer/component").default>}
   *
   * @example
   * ```javascript
   * const allBlocks = this.blocks.listBlocks();
   * ```
   */
  listBlocks() {
    return Array.from(blockRegistry.values());
  }

  /**
   * Returns all registered blocks with their metadata.
   * Useful for admin UIs and documentation generation.
   *
   * @returns {Array<{name: string, component: typeof import("@glimmer/component").default, metadata: Object}>}
   *
   * @example
   * ```javascript
   * const blocksInfo = this.blocks.listBlocksWithMetadata();
   * blocksInfo.forEach(({ name, metadata }) => {
   *   console.log(name, metadata.description, metadata.args);
   * });
   * ```
   */
  listBlocksWithMetadata() {
    return Array.from(blockRegistry.entries()).map(([name, component]) => ({
      name,
      component,
      metadata: component.blockMetadata,
    }));
  }

  // ============================================================================
  // Condition Evaluation Methods (moved from BlockConditionEvaluator)
  // ============================================================================

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
        this.#registerConditionType(exported);
      }
    }
  }

  /**
   * Internal registration method for condition types.
   * Validates the condition class and creates an instance with owner set.
   *
   * @param {typeof import("discourse/blocks/conditions").BlockCondition} ConditionClass
   */
  #registerConditionType(ConditionClass) {
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

    if (this.#conditionTypes.has(ConditionClass.type)) {
      raiseValidationError(
        `Condition type "${ConditionClass.type}" is already registered`
      );
      return;
    }

    const instance = new ConditionClass();
    setOwner(instance, getOwner(this));
    this.#conditionTypes.set(ConditionClass.type, instance);
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
  registerConditionType(ConditionClass) {
    this.#registerConditionType(ConditionClass);
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

    const conditionInstance = this.#conditionTypes.get(type);

    if (!conditionInstance) {
      const availableTypes = [...this.#conditionTypes.keys()].join(", ");
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
    const conditionInstance = this.#conditionTypes.get(type);

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
  hasConditionType(type) {
    return this.#conditionTypes.has(type);
  }

  /**
   * Returns all registered condition type names.
   * Useful for debugging and error messages.
   *
   * @returns {string[]}
   */
  getRegisteredConditionTypes() {
    return [...this.#conditionTypes.keys()];
  }
}
