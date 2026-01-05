import { DEBUG } from "@glimmer/env";
import { raiseBlockError } from "discourse/lib/blocks/error";
import { VALID_BLOCK_NAME_PATTERN } from "discourse/lib/blocks/patterns";

// Re-export for backwards compatibility
export { VALID_BLOCK_NAME_PATTERN };

/**
 * A block class decorated with `@block`.
 *
 * @typedef {typeof import("@glimmer/component").default & { blockName: string, blockMetadata: Object }} BlockClass
 */

/**
 * A factory function that returns a Promise resolving to a BlockClass or module with default export.
 *
 * @typedef {() => Promise<BlockClass | { default: BlockClass }>} BlockFactory
 */

/**
 * Registry entry: either a resolved BlockClass or a factory function for lazy loading.
 *
 * @typedef {BlockClass | BlockFactory} BlockRegistryEntry
 */

/**
 * Registry of block components registered via `@block` decorator and `api.registerBlock()`.
 * Maps block names to their component classes or factory functions.
 *
 * @type {Map<string, BlockRegistryEntry>}
 */
export const blockRegistry = new Map();

/**
 * Cache for resolved factory functions.
 * Once a factory is resolved, the result is stored here to avoid re-resolving.
 *
 * @type {Map<string, BlockClass>}
 */
const resolvedFactoryCache = new Map();

/**
 * Whether the block registry is locked (no new registrations allowed).
 * Gets locked when the first renderBlocks() config is registered.
 */
let registryLocked = false;

/**
 * Locks the registry, preventing further registrations.
 * Called when the first renderBlocks() config is registered.
 *
 * @internal
 */
export function _lockBlockRegistry() {
  registryLocked = true;
}

/**
 * Returns whether the block registry is locked.
 *
 * @returns {boolean}
 */
export function isBlockRegistryLocked() {
  return registryLocked;
}

/**
 * Registers a block component in the registry.
 * Must be called before any renderBlocks() configuration is registered.
 *
 * The block component must be decorated with `@block` and have:
 * - `blockName` static property (set by the decorator)
 * - `blockMetadata` static property (set by the decorator)
 *
 * @param {typeof import("@glimmer/component").default} BlockClass - The block component class
 * @throws {Error} If called after registry is locked, or if block is invalid
 *
 * @example
 * ```javascript
 * import { withPluginApi } from "discourse/lib/plugin-api";
 * import MyBlock from "../blocks/my-block";
 *
 * export default {
 *   initialize() {
 *     withPluginApi("1.0", (api) => {
 *       api.registerBlock(MyBlock);
 *     });
 *   },
 * };
 * ```
 */
export function _registerBlock(BlockClass) {
  if (registryLocked) {
    raiseBlockError(
      `Cannot register block "${BlockClass?.blockName || BlockClass?.name}": ` +
        `the block registry is locked. Blocks must be registered before ` +
        `any renderBlocks() configuration is set up.`
    );
    return;
  }

  if (!BlockClass?.blockName) {
    raiseBlockError(
      `Block class "${BlockClass?.name}" must be decorated with @block to be registered.`
    );
    return;
  }

  // Validate block name format
  if (!VALID_BLOCK_NAME_PATTERN.test(BlockClass.blockName)) {
    raiseBlockError(
      `Block name "${BlockClass.blockName}" is invalid. ` +
        `Block names must start with a letter and contain only lowercase letters, numbers, and hyphens.`
    );
    return;
  }

  if (blockRegistry.has(BlockClass.blockName)) {
    raiseBlockError(`Block "${BlockClass.blockName}" is already registered.`);
    return;
  }

  blockRegistry.set(BlockClass.blockName, BlockClass);
}

/**
 * Checks if a registry entry is a factory function (not a resolved class).
 *
 * Factory functions are plain functions without a `blockName` property.
 * BlockClasses have `blockName` set by the `@block` decorator.
 *
 * @param {BlockRegistryEntry} entry - The registry entry to check.
 * @returns {boolean} True if the entry is a factory function.
 */
export function isBlockFactory(entry) {
  return typeof entry === "function" && !entry.blockName;
}

/**
 * Registers a factory function for lazy loading a block.
 *
 * The factory will be called when the block is first needed. It must return
 * a Promise that resolves to a BlockClass (or a module with a default export).
 *
 * @param {string} name - The name to register the block under.
 * @param {BlockFactory} factory - Factory function returning Promise<BlockClass>.
 * @throws {Error} If registry is locked, name is invalid, or factory is not a function.
 *
 * @example
 * ```javascript
 * api.registerBlock("hero-banner", () => import("../blocks/hero-banner"));
 * // Block will be loaded when first used
 * ```
 *
 * @internal
 */
export function _registerBlockFactory(name, factory) {
  if (registryLocked) {
    raiseBlockError(
      `Cannot register block "${name}": ` +
        `the block registry is locked. Blocks must be registered before ` +
        `any renderBlocks() configuration is set up.`
    );
    return;
  }

  if (!VALID_BLOCK_NAME_PATTERN.test(name)) {
    raiseBlockError(
      `Block name "${name}" is invalid. ` +
        `Block names must start with a letter and contain only lowercase letters, numbers, and hyphens.`
    );
    return;
  }

  if (typeof factory !== "function") {
    raiseBlockError(
      `Block factory for "${name}" must be a function that returns a Promise<BlockClass>.`
    );
    return;
  }

  if (blockRegistry.has(name)) {
    raiseBlockError(`Block "${name}" is already registered.`);
    return;
  }

  blockRegistry.set(name, factory);
}

/**
 * Checks if a block is registered (by name or class reference).
 *
 * This is a synchronous check that does not resolve factory functions.
 * Use this to verify a block exists before attempting resolution.
 *
 * @param {string | BlockClass} nameOrClass - Block name string or BlockClass.
 * @returns {boolean} True if the block is registered.
 */
export function hasBlock(nameOrClass) {
  if (typeof nameOrClass === "string") {
    return blockRegistry.has(nameOrClass);
  }
  return nameOrClass?.blockName && blockRegistry.has(nameOrClass.blockName);
}

/**
 * Checks if a block is registered and fully resolved (not a pending factory).
 *
 * Returns false for unregistered blocks or blocks that are registered
 * as factory functions but haven't been resolved yet.
 *
 * @param {string} name - The block name to check.
 * @returns {boolean} True if registered and resolved.
 */
export function isBlockResolved(name) {
  if (!blockRegistry.has(name)) {
    return false;
  }
  const entry = blockRegistry.get(name);
  return !isBlockFactory(entry);
}

/**
 * Resolves a block reference (string name or class) to a BlockClass.
 *
 * - If given a BlockClass, returns it directly.
 * - If given a string, looks up in registry and resolves factory if needed.
 * - Caches resolved factories to avoid re-resolving.
 *
 * @param {string | BlockClass} nameOrClass - Block name string or BlockClass.
 * @returns {Promise<BlockClass>} The resolved block class.
 * @throws {Error} If block not found or factory resolution fails.
 *
 * @example
 * ```javascript
 * const BlockClass = await resolveBlock("hero-banner");
 * const BlockClass = await resolveBlock(HeroBanner); // Returns directly
 * ```
 */
export async function resolveBlock(nameOrClass) {
  // If already a class, return it directly
  if (typeof nameOrClass !== "string") {
    if (!nameOrClass?.blockName) {
      raiseBlockError(
        `Invalid block reference: expected string name or @block-decorated class, ` +
          `got ${typeof nameOrClass}.`
      );
    }
    return nameOrClass;
  }

  const name = nameOrClass;

  // Check resolved cache first
  if (resolvedFactoryCache.has(name)) {
    return resolvedFactoryCache.get(name);
  }

  // Look up in registry
  if (!blockRegistry.has(name)) {
    raiseBlockError(
      `Block "${name}" is not registered. ` +
        `Use api.registerBlock() in a pre-initializer before any renderBlocks() configuration.`
    );
  }

  const entry = blockRegistry.get(name);

  // If already a class (not a factory), return it
  if (!isBlockFactory(entry)) {
    return entry;
  }

  // Resolve factory
  try {
    const result = await entry();
    // Handle both direct class and module with default export
    const BlockClass = result?.default ?? result;

    if (!BlockClass?.blockName) {
      raiseBlockError(
        `Block factory for "${name}" did not return a valid @block-decorated class.`
      );
    }

    // Validate that the resolved block's name matches the registered name
    if (BlockClass.blockName !== name) {
      raiseBlockError(
        `Block factory registered as "${name}" resolved to a block with ` +
          `blockName "${BlockClass.blockName}". The registered name must match ` +
          `the block's @block decorator name.`
      );
    }

    // Cache the resolved class
    resolvedFactoryCache.set(name, BlockClass);

    // Update the main registry for future sync lookups
    blockRegistry.set(name, BlockClass);

    return BlockClass;
  } catch (error) {
    if (error.name === "BlockError") {
      throw error;
    }
    raiseBlockError(
      `Failed to resolve block factory for "${name}": ${error.message}`
    );
  }
}

/**
 * Stores the initial locked state to allow correct reset after tests.
 * @type {boolean | null}
 */
let testRegistryLockedState = null;

/**
 * Unlocks the block registry for testing purposes.
 * Call this before registering blocks in tests.
 * Only available in DEBUG mode.
 */
export function withTestBlockRegistration(callback) {
  if (!DEBUG) {
    return;
  }

  if (testRegistryLockedState === null) {
    testRegistryLockedState = registryLocked;
  }

  registryLocked = false;
  try {
    callback();
  } finally {
    registryLocked = testRegistryLockedState;
  }
}

/**
 * Resets the block registry for testing purposes.
 * Clears all registered blocks and restores the original locked state.
 * Only available in DEBUG mode.
 */
export function resetBlockRegistryForTesting() {
  if (!DEBUG) {
    return;
  }

  blockRegistry.clear();
  resolvedFactoryCache.clear();

  if (testRegistryLockedState !== null) {
    registryLocked = testRegistryLockedState;
    testRegistryLockedState = null;
  } else {
    registryLocked = false;
  }
}
