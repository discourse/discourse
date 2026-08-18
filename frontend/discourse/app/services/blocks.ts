import { getOwner, setOwner } from "@ember/owner";
import Service from "@ember/service";
import { _hasLayout } from "discourse/blocks/block-outlet";
import type { BlockCondition } from "discourse/blocks/conditions";
import type { BlockMetadata, LayoutEntry } from "discourse/blocks/types";
import { debugHooks } from "discourse/lib/blocks/-internals/debug-hooks";
import { getBlockMetadata } from "discourse/lib/blocks/-internals/decorator";
import {
  type ConditionEvaluationContext,
  evaluateConditions,
} from "discourse/lib/blocks/-internals/matching/condition-evaluator";
import {
  getAllBlockEntries,
  getBlockEntry,
  hasBlock,
  isBlockFactory,
  resolveBlock,
} from "discourse/lib/blocks/-internals/registry/block";
import { getAllConditionTypeEntries } from "discourse/lib/blocks/-internals/registry/condition";
import { getAllOutlets } from "discourse/lib/blocks/-internals/registry/outlet";
import type {
  BlockClass,
  BlockRegistryEntry,
} from "discourse/lib/blocks/-internals/types";
import { validateConditions } from "discourse/lib/blocks/-internals/validation/conditions";

/**
 * A registered block paired with its `@block` decorator metadata, as
 * returned by `listBlocksWithMetadata()`.
 */
export interface BlockInfo {
  /** The registered block name. */
  name: string;
  /** The block's registry entry: a resolved class, or a lazy factory. */
  component: BlockRegistryEntry;
  /** The block's `@block` decorator metadata, or `null` if unavailable. */
  metadata: BlockMetadata | null;
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
 * ## Debug Support
 *
 * - `showGhosts` - Check if visual overlay is enabled (for rendering ghost blocks)
 *
 * @experimental This API is under active development and may change or be removed
 * in future releases without prior notice. Use with caution in production environments.
 */
export default class Blocks extends Service {
  /**
   * Map of condition type names to their instances.
   * Built lazily from the condition type registry when first accessed.
   */
  #conditionInstances = new Map<string, BlockCondition>();

  /**
   * Tracks the registry size at last initialization to detect new registrations.
   *
   * We use size-based detection (rather than tracking individual type names) because:
   * 1. Condition types are only ever added, never removed
   * 2. Size comparison is O(1) vs O(n) for set difference
   * 3. Avoids allocating a Set<string> for tracking
   *
   * When `registry.size` is greater than `#lastKnownRegistrySize`, we know new
   * types were registered and need to create instances for them.
   */
  #lastKnownRegistrySize = 0;

  /*
   * Block Outlet Methods
   */

  /**
   * Returns all registered block outlet names (both core and custom).
   *
   * Core outlets are defined in `lib/registry/block-outlets.ts`. Custom outlets
   * are registered by plugins and themes via `api.registerBlockOutlet()`.
   *
   * @returns Array of outlet names (e.g., ["hero-blocks", "homepage-blocks", ...]).
   *
   * @example
   * ```javascript
   * const outlets = this.blocks.listOutlets();
   * ```
   */
  listOutlets(): string[] {
    return getAllOutlets();
  }

  /**
   * Checks if a layout has been registered for a given block outlet.
   *
   * A layout is registered when a plugin or theme calls `api.renderBlocks()`
   * for an outlet. This method allows checking layout presence outside of
   * `BlockOutlet` templates.
   *
   * @param outletName - The outlet identifier to check.
   * @returns True if a layout is registered for this outlet.
   *
   * @example
   * ```javascript
   * if (this.blocks.hasLayout("homepage-blocks")) {
   *   // Outlet has blocks registered
   * }
   * ```
   */
  hasLayout(outletName: string): boolean {
    return _hasLayout(outletName);
  }

  /*
   * Block Registry Methods
   */

  /**
   * Gets a registered block by name.
   *
   * @param name - The block name (e.g., "hero-banner")
   * @returns The block entry, or undefined if not found
   *
   * @example
   * ```javascript
   * const HeroBanner = this.blocks.getBlock("hero-banner");
   * ```
   */
  getBlock(name: string): BlockRegistryEntry | undefined {
    return getBlockEntry(name);
  }

  /**
   * Checks if a block is registered.
   *
   * @param name - The block name
   *
   * @example
   * ```javascript
   * if (this.blocks.hasBlock("hero-banner")) {
   *   // Block is available
   * }
   * ```
   */
  hasBlock(name: string): boolean {
    return hasBlock(name);
  }

  /**
   * Returns all registered block entries.
   *
   * @example
   * ```javascript
   * const allBlocks = this.blocks.listBlocks();
   * ```
   */
  listBlocks(): BlockRegistryEntry[] {
    return getAllBlockEntries().map(([, entry]) => entry);
  }

  /**
   * Returns all registered blocks with their metadata.
   * Useful for admin UIs and documentation generation.
   *
   * @example
   * ```javascript
   * const blocksInfo = this.blocks.listBlocksWithMetadata();
   * blocksInfo.forEach(({ name, metadata }) => {
   *   console.log(name, metadata.description, metadata.args);
   * });
   * ```
   */
  listBlocksWithMetadata(): BlockInfo[] {
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
   * @param name - The block name (e.g., "hero-banner").
   * @returns The resolved block class, or undefined if not found.
   *
   * @example
   * ```javascript
   * const HeroBanner = await this.blocks.getBlockAsync("hero-banner");
   * if (HeroBanner) {
   *   // Block is ready to use
   * }
   * ```
   */
  async getBlockAsync(name: string): Promise<BlockClass | undefined> {
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
   * @param name - The block name.
   * @returns True if registered and immediately available.
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
  isBlockReady(name: string): boolean {
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
  #lazilyInitializeConditionInstances(): void {
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
   * @param type - The condition type name.
   * @param ConditionClass - The condition class.
   */
  #createConditionInstance(
    type: string,
    ConditionClass: typeof BlockCondition
  ): void {
    const instance = new ConditionClass();
    // This service instance is always Ember-owned (services are only ever
    // instantiated through the DI container), so `getOwner(this)` is never
    // undefined here.
    setOwner(instance, getOwner(this)!);
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
   * @param conditionSpec - Condition spec(s) to validate.
   * @throws A `BlockError` if validation fails.
   */
  validate(conditionSpec: LayoutEntry["conditions"]): void {
    this.#lazilyInitializeConditionInstances();
    validateConditions(conditionSpec, this.#conditionInstances);
  }

  /**
   * Evaluates condition specs at render time.
   * Recursively evaluates nested conditions with AND/OR/NOT logic.
   *
   * @param conditionSpec - Condition spec(s) to evaluate.
   * @param context - Evaluation context.
   * @returns True if conditions pass, false otherwise.
   */
  evaluate(
    conditionSpec: LayoutEntry["conditions"],
    context: ConditionEvaluationContext = {}
  ): boolean {
    this.#lazilyInitializeConditionInstances();
    return evaluateConditions(conditionSpec, this.#conditionInstances, context);
  }

  /**
   * Checks if a condition type is registered.
   *
   * @param type - The condition type name
   */
  hasConditionType(type: string): boolean {
    this.#lazilyInitializeConditionInstances();
    return this.#conditionInstances.has(type);
  }

  /**
   * Returns all registered condition type names.
   * Useful for debugging and error messages.
   */
  getRegisteredConditionTypes(): string[] {
    this.#lazilyInitializeConditionInstances();
    return [...this.#conditionInstances.keys()];
  }

  /*
   * Debug Methods
   */

  /**
   * Returns whether the debug visual overlay is enabled.
   *
   * Container blocks can use this to conditionally render ghost blocks
   * for children they choose not to display.
   *
   * @returns True if the visual overlay (ghost blocks) is enabled.
   *
   * @example
   * ```javascript
   * if (this.blocks.showGhosts) {
   *   // Render ghost blocks for hidden children
   * }
   * ```
   */
  get showGhosts(): boolean {
    return debugHooks.isGhostBlocksEnabled;
  }
}
