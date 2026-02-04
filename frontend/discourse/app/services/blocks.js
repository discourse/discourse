// @ts-check
import { getOwner, setOwner } from "@ember/owner";
import Service from "@ember/service";
import { getBlockMetadata } from "discourse/lib/blocks/-internals/decorator";
import { evaluateConditions } from "discourse/lib/blocks/-internals/matching/condition-evaluator";
import {
  getAllBlockEntries,
  getBlockEntry,
  hasBlock,
  isBlockFactory,
  resolveBlock,
} from "discourse/lib/blocks/-internals/registry/block";
import { getAllConditionTypeEntries } from "discourse/lib/blocks/-internals/registry/condition";
import { validateConditions } from "discourse/lib/blocks/-internals/validation/conditions";

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
 * Core blocks are auto-discovered from `discourse/blocks/builtin`.
 * Theme/plugin blocks are registered via `api.registerBlock()` in pre-initializers.
 *
 * ## Condition Evaluation
 *
 * Evaluates block render conditions at runtime:
 * - `evaluate(conditionSpec)` - Evaluate condition(s)
 * - `validate(conditionSpec)` - Validate condition(s) at registration time
 *
 * Custom condition types are registered via `api.registerBlockConditionType()` in pre-initializers.
 * Built-in condition types are auto-discovered from `discourse/blocks/conditions`.
 *
 * Supports boolean combinators:
 * - Array of conditions: AND logic (all must pass)
 * - `{ any: [...] }`: OR logic (at least one must pass)
 * - `{ not: {...} }`: NOT logic (must fail)
 *
 * @experimental This API is under active development and may change or be removed
 * in future releases without prior notice. Use with caution in production environments.
 *
 * @class Blocks
 * @extends Service
 */
export default class Blocks extends Service {
  /**
   * Map of condition type names to their instances.
   * Built lazily from the condition type registry when first accessed.
   *
   * @type {Map<string, import("discourse/blocks/conditions").BlockCondition>}
   */
  #conditionInstances = new Map();

  /**
   * Tracks the registry size at last initialization to detect new registrations.
   *
   * We use size-based detection (rather than tracking individual type names) because:
   * 1. Condition types are only ever added, never removed
   * 2. Size comparison is O(1) vs O(n) for set difference
   * 3. Avoids allocating a Set<string> for tracking
   *
   * When registry.size > #lastKnownRegistrySize, we know new types were registered
   * and need to create instances for them.
   *
   * @type {number}
   */
  #lastKnownRegistrySize = 0;

  /*
   * Block Registry Methods
   */

  /**
   * Gets a registered block by name.
   *
   * @param {string} name - The block name (e.g., "hero-banner")
   * @returns {import("discourse/lib/blocks/-internals/registry/block").BlockRegistryEntry|undefined} The block entry, or undefined if not found
   *
   * @example
   * ```javascript
   * const HeroBanner = this.blocks.getBlock("hero-banner");
   * ```
   */
  getBlock(name) {
    return getBlockEntry(name);
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
    return hasBlock(name);
  }

  /**
   * Returns all registered block entries.
   *
   * @returns {Array<import("discourse/lib/blocks/-internals/registry/block").BlockRegistryEntry>}
   *
   * @example
   * ```javascript
   * const allBlocks = this.blocks.listBlocks();
   * ```
   */
  listBlocks() {
    return getAllBlockEntries().map(([, entry]) => entry);
  }

  /**
   * Returns all registered blocks with their metadata.
   * Useful for admin UIs and documentation generation.
   *
   * @returns {Array<{name: string, component: import("discourse/lib/blocks/-internals/registry/block").BlockRegistryEntry, metadata: Object}>}
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
    return getAllBlockEntries().map(([name, component]) => ({
      name,
      component,
      metadata: getBlockMetadata(component),
    }));
  }

  /**
   * Asynchronously gets a registered block by name, resolving factories if needed.
   *
   * Unlike `getBlock()` which returns the raw registry entry (which may be a factory),
   * this method ensures the returned value is always a resolved BlockClass.
   *
   * @param {string} name - The block name (e.g., "hero-banner").
   * @returns {Promise<import("discourse/lib/blocks/-internals/registry/block").BlockClass|undefined>}
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
    if (!hasBlock(name)) {
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
    if (!hasBlock(name)) {
      return false;
    }
    const entry = getBlockEntry(name);
    return !isBlockFactory(entry);
  }

  /*
   * Condition Evaluation Methods
   */

  /**
   * Lazily initializes condition instances from the registry.
   *
   * This deferred initialization pattern handles the timing issue where:
   * 1. Service is instantiated early (e.g., during plugin API usage)
   * 2. Core conditions are registered later by the pre-initializer
   * 3. Service needs to pick up the newly registered conditions
   *
   * Called at the start of validate(), evaluate(), and other condition methods.
   */
  #lazilyInitializeConditionInstances() {
    const entries = getAllConditionTypeEntries();

    // Only rebuild if registry has grown since last check
    if (entries.length === this.#lastKnownRegistrySize) {
      return;
    }

    // Create instances for any new condition types
    for (const [type, ConditionClass] of entries) {
      if (!this.#conditionInstances.has(type)) {
        this.#createConditionInstance(type, ConditionClass);
      }
    }

    this.#lastKnownRegistrySize = entries.length;
  }

  /**
   * Creates an instance of a condition class and stores it in the instances map.
   * Sets the owner on the instance to enable service injection.
   *
   * @param {string} type - The condition type name.
   * @param {typeof import("discourse/blocks/conditions").BlockCondition} ConditionClass - The condition class.
   */
  #createConditionInstance(type, ConditionClass) {
    const instance = new ConditionClass();
    setOwner(instance, getOwner(this));
    this.#conditionInstances.set(type, instance);
  }

  /**
   * Validates condition specs at block registration time.
   * Recursively validates nested conditions in `any` and `not` combinators.
   *
   * Throws BlockError objects so callers can decide how to format
   * the final error with appropriate context. The error object includes a
   * `path` property indicating where in the conditions the error occurred
   * (relative to the conditions root, e.g., "params.categoryId").
   *
   * @param {Object|Array<Object>} conditionSpec - Condition spec(s) to validate.
   * @throws {BlockError} If validation fails.
   */
  validate(conditionSpec) {
    this.#lazilyInitializeConditionInstances();
    validateConditions(conditionSpec, this.#conditionInstances);
  }

  /**
   * Evaluates condition specs at render time.
   * Recursively evaluates nested conditions with AND/OR/NOT logic.
   *
   * @param {Object|Array<Object>} conditionSpec - Condition spec(s) to evaluate.
   * @param {Object} [context] - Evaluation context.
   * @param {boolean} [context.debug] - Enable debug logging for this evaluation.
   * @param {number} [context._depth] - Internal: nesting depth for logging.
   * @param {Object} [context.outletArgs] - Outlet arguments passed to conditions.
   * @returns {boolean} True if conditions pass, false otherwise.
   */
  evaluate(conditionSpec, context = {}) {
    this.#lazilyInitializeConditionInstances();
    return evaluateConditions(conditionSpec, this.#conditionInstances, context);
  }

  /**
   * Checks if a condition type is registered.
   *
   * @param {string} type - The condition type name
   * @returns {boolean}
   */
  hasConditionType(type) {
    this.#lazilyInitializeConditionInstances();
    return this.#conditionInstances.has(type);
  }

  /**
   * Returns all registered condition type names.
   * Useful for debugging and error messages.
   *
   * @returns {string[]}
   */
  getRegisteredConditionTypes() {
    this.#lazilyInitializeConditionInstances();
    return [...this.#conditionInstances.keys()];
  }
}
