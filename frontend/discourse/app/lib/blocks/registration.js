import { DEBUG } from "@glimmer/env";
import * as coreBlocks from "discourse/blocks/core";
import { raiseBlockError } from "discourse/lib/blocks/error";

/**
 * Valid block name pattern: lowercase letters, numbers, and hyphens.
 * Must start with a letter. Examples: "hero-banner", "my-block-1"
 */
const VALID_BLOCK_NAME_PATTERN = /^[a-z][a-z0-9-]*$/;

/**
 * Registry of block components registered via `@block` decorator and `api.registerBlock()`.
 * Maps block names to their component classes.
 *
 * @type {Map<string, typeof import("@glimmer/component").default>}
 */
export const blockRegistry = new Map();

/**
 * Whether the block registry is locked (no new registrations allowed).
 * Gets locked when the first renderBlocks() config is registered.
 */
let registryLocked = false;

/**
 * Core block auto-discovery at module load time.
 * Similar to how transformers initialize validTransformerNames.
 *
 * This runs before any initializers, ensuring core blocks are
 * available immediately when the module is imported.
 */
for (const exported of Object.values(coreBlocks)) {
  // Check if it's a @block-decorated component (has blockName set by decorator)
  if (typeof exported === "function" && exported.blockName) {
    blockRegistry.set(exported.blockName, exported);
  }
}

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

  // Re-register core blocks
  for (const exported of Object.values(coreBlocks)) {
    if (typeof exported === "function" && exported.blockName) {
      blockRegistry.set(exported.blockName, exported);
    }
  }

  if (testRegistryLockedState !== null) {
    registryLocked = testRegistryLockedState;
    testRegistryLockedState = null;
  } else {
    registryLocked = false;
  }
}
