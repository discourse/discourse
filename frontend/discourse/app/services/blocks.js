import { getOwner, setOwner } from "@ember/owner";
import Service from "@ember/service";
import * as conditions from "discourse/blocks/conditions";
import { isDecoratedCondition } from "discourse/blocks/conditions/decorator";
import { validateConditions } from "discourse/lib/blocks/condition-validation";
import {
  DEBUG_CALLBACK,
  getDebugCallback,
  getLoggerInterface,
} from "discourse/lib/blocks/debug-hooks";
import { raiseBlockError } from "discourse/lib/blocks/error";
import {
  blockRegistry,
  isBlockFactory,
  resolveBlock,
} from "discourse/lib/blocks/registration";

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
    this.#discoverBuiltInConditions();
  }

  /*
   * Block Registry Methods
   */

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

  /**
   * Asynchronously gets a registered block by name, resolving factories if needed.
   *
   * Unlike `getBlock()` which returns the raw registry entry (which may be a factory),
   * this method ensures the returned value is always a resolved BlockClass.
   *
   * @param {string} name - The block name (e.g., "hero-banner").
   * @returns {Promise<typeof import("@glimmer/component").default|undefined>}
   *   The resolved block class, or undefined if not found.
   *
   * @example
   * ```javascript
   * const HeroBanner = await this.blocks.getBlockAsync("hero-banner");
   * if (HeroBanner) {
   *   // Block is ready to use
   * }
   * ```
   */
  async getBlockAsync(name) {
    if (!blockRegistry.has(name)) {
      return undefined;
    }
    try {
      return await resolveBlock(name);
    } catch {
      return undefined;
    }
  }

  /**
   * Checks if a block is registered and fully resolved (not a pending factory).
   *
   * Use this to check if a block is immediately available without needing async resolution.
   * Returns false for unregistered blocks or blocks that are registered as factory functions
   * but haven't been resolved yet.
   *
   * @param {string} name - The block name.
   * @returns {boolean} True if registered and immediately available.
   *
   * @example
   * ```javascript
   * if (this.blocks.isBlockReady("hero-banner")) {
   *   // Block is available synchronously
   *   const HeroBanner = this.blocks.getBlock("hero-banner");
   * } else {
   *   // Block needs async resolution
   *   const HeroBanner = await this.blocks.getBlockAsync("hero-banner");
   * }
   * ```
   */
  isBlockReady(name) {
    if (!blockRegistry.has(name)) {
      return false;
    }
    const entry = blockRegistry.get(name);
    return !isBlockFactory(entry);
  }

  /*
   * Condition Evaluation Methods
   */

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
   * Validates that the class was decorated with `@blockCondition` and creates
   * an instance with owner set.
   *
   * @param {typeof import("discourse/blocks/conditions").BlockCondition} ConditionClass
   */
  #registerConditionType(ConditionClass) {
    // Ensure the class was created by the @blockCondition decorator
    if (!isDecoratedCondition(ConditionClass)) {
      raiseBlockError(
        `${ConditionClass.name} must use the @blockCondition decorator. ` +
          `Manual inheritance from BlockCondition is not allowed.`
      );
      return;
    }

    if (this.#conditionTypes.has(ConditionClass.type)) {
      raiseBlockError(
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
   * The condition class must be decorated with `@blockCondition` and extend
   * `BlockCondition`.
   *
   * @param {typeof import("discourse/blocks/conditions").BlockCondition} ConditionClass
   *
   * @example
   * ```javascript
   * import { blockCondition, BlockCondition } from "discourse/blocks/conditions";
   *
   * @blockCondition({
   *   type: "my-condition",
   *   validArgKeys: ["enabled"],
   * })
   * class BlockMyCondition extends BlockCondition {
   *   evaluate(args) { return args.enabled ?? true; }
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
   * Throws BlockValidationError objects so callers can decide how to format
   * the final error with appropriate context. The error object includes a
   * `conditionPath` property indicating where in the config the error occurred.
   *
   * @param {Object|Array<Object>} conditionSpec - Condition spec(s) to validate.
   * @param {string} [path="conditions"] - The path to this condition in the config tree.
   * @throws {BlockValidationError} If validation fails.
   */
  validate(conditionSpec, path = "conditions") {
    validateConditions(conditionSpec, this.#conditionTypes, path);
  }

  /**
   * Evaluates condition specs at render time.
   * Recursively evaluates nested conditions with AND/OR/NOT logic.
   *
   * @param {Object|Array<Object>} conditionSpec - Condition spec(s) to evaluate
   * @param {Object} [context] - Evaluation context
   * @param {boolean} [context.debug] - Enable debug logging for this evaluation
   * @param {number} [context._depth] - Internal: nesting depth for logging
   * @returns {boolean} True if conditions pass, false otherwise
   */
  evaluate(conditionSpec, context = {}) {
    const isLoggingEnabled = context.debug ?? false;
    const depth = context._depth ?? 0;

    // Get logging callbacks (null if dev tools not loaded or logging disabled)
    const conditionLog = isLoggingEnabled
      ? getDebugCallback(DEBUG_CALLBACK.CONDITION_LOG)
      : null;
    const combinatorLog = isLoggingEnabled
      ? getDebugCallback(DEBUG_CALLBACK.COMBINATOR_LOG)
      : null;
    const conditionResultLog = isLoggingEnabled
      ? getDebugCallback(DEBUG_CALLBACK.CONDITION_RESULT)
      : null;
    // Get logger interface for conditions (e.g., route condition needs to log params)
    const logger = isLoggingEnabled ? getLoggerInterface() : null;

    if (!conditionSpec) {
      return true;
    }

    // Array of conditions (AND logic - all must pass)
    if (Array.isArray(conditionSpec)) {
      // Empty array is vacuous truth - no conditions to fail
      if (conditionSpec.length === 0) {
        return true;
      }

      // Log combinator BEFORE children (result=null as placeholder)
      conditionLog?.({
        type: "AND",
        args: `${conditionSpec.length} conditions`,
        result: null,
        depth,
        conditionSpec,
      });

      let andResult = true;
      for (const condition of conditionSpec) {
        const result = this.evaluate(condition, {
          debug: isLoggingEnabled,
          _depth: depth + 1,
          outletArgs: context.outletArgs,
        });
        if (!result) {
          andResult = false;
          // Short-circuit only when not debugging - evaluate all for debug visibility
          if (!isLoggingEnabled) {
            break;
          }
        }
      }

      // Update combinator with actual result
      combinatorLog?.({ conditionSpec, result: andResult });
      return andResult;
    }

    // OR combinator (at least one must pass)
    if (conditionSpec.any !== undefined) {
      // Empty OR array means no conditions can pass
      if (conditionSpec.any.length === 0) {
        return false;
      }

      // Log combinator BEFORE children (result=null as placeholder)
      conditionLog?.({
        type: "OR",
        args: `${conditionSpec.any.length} conditions`,
        result: null,
        depth,
        conditionSpec,
      });

      let orResult = false;
      for (const condition of conditionSpec.any) {
        const result = this.evaluate(condition, {
          debug: isLoggingEnabled,
          _depth: depth + 1,
          outletArgs: context.outletArgs,
        });
        if (result) {
          orResult = true;
          // Short-circuit only when not debugging - evaluate all for debug visibility
          if (!isLoggingEnabled) {
            break;
          }
        }
      }

      // Update combinator with actual result
      combinatorLog?.({ conditionSpec, result: orResult });
      return orResult;
    }

    // NOT combinator (must fail)
    if (conditionSpec.not !== undefined) {
      // Log combinator BEFORE children (result=null as placeholder)
      conditionLog?.({
        type: "NOT",
        args: null,
        result: null,
        depth,
        conditionSpec,
      });

      const innerResult = this.evaluate(conditionSpec.not, {
        debug: isLoggingEnabled,
        _depth: depth + 1,
        outletArgs: context.outletArgs,
      });
      const notResult = !innerResult;

      // Update combinator with actual result
      combinatorLog?.({ conditionSpec, result: notResult });
      return notResult;
    }

    // Single condition with type
    const { type, ...args } = conditionSpec;
    const conditionInstance = this.#conditionTypes.get(type);

    if (!conditionInstance) {
      conditionLog?.({
        type: `unknown "${type}"`,
        args,
        result: false,
        depth,
      });
      return false;
    }

    // Resolve value for logging (handles source, path, and other condition-specific values)
    let resolvedValue;
    if (isLoggingEnabled) {
      resolvedValue = conditionInstance.getResolvedValueForLogging(
        args,
        context
      );
    }

    // Log condition BEFORE evaluate so nested logs appear underneath
    conditionLog?.({
      type,
      args,
      result: null,
      depth,
      resolvedValue,
      conditionSpec,
    });

    // Pass context to evaluate so conditions can access outletArgs and log nested items
    const evalContext = {
      debug: isLoggingEnabled,
      _depth: depth,
      outletArgs: context.outletArgs,
      logger,
    };
    const result = conditionInstance.evaluate(args, evalContext);

    // Update the condition's result after evaluate
    conditionResultLog?.({ conditionSpec, result });
    return result;
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
