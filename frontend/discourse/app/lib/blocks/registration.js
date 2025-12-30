import { DEBUG } from "@glimmer/env";
import { consolePrefix } from "discourse/lib/source-identifier";

/**
 * Registry of block components registered via `@block` decorator and `api.registerBlock()`.
 * Maps block names to their component classes.
 *
 * @type {Map<string, typeof import("@glimmer/component").default>}
 */
export const blockRegistry = new Map();

/**
 * Whether the block registry has been frozen.
 * Once frozen, no new blocks can be registered.
 */
let registryFrozen = false;

/**
 * Raises a validation error in dev/test, logs warning in production.
 *
 * @param {string} message - The error message
 */
function raiseValidationError(message) {
  const prefixedMessage = `${consolePrefix()} ${message}`;
  if (DEBUG) {
    throw new Error(prefixedMessage);
  } else {
    // eslint-disable-next-line no-console
    console.warn(`[Block registry] ${prefixedMessage}`);
  }
}

/**
 * Registers a block component in the registry.
 * Must be called in a pre-initializer before `freeze-valid-blocks`.
 *
 * The block component must be decorated with `@block` and have:
 * - `blockName` static property (set by the decorator)
 * - `blockMetadata` static property (set by the decorator)
 *
 * @param {typeof import("@glimmer/component").default} BlockClass - The block component class
 * @throws {Error} If called after registry is frozen, or if block is invalid
 *
 * @example
 * ```javascript
 * // In a pre-initializer (before freeze-valid-blocks)
 * import { withPluginApi } from "discourse/lib/plugin-api";
 * import MyBlock from "../blocks/my-block";
 *
 * export default {
 *   before: "freeze-valid-blocks",
 *   initialize() {
 *     withPluginApi("1.0", (api) => {
 *       api.registerBlock(MyBlock);
 *     });
 *   },
 * };
 * ```
 */
export function _registerBlock(BlockClass) {
  if (registryFrozen) {
    raiseValidationError(
      `Cannot register block "${BlockClass?.blockName || BlockClass?.name}": ` +
        `the block registry is frozen. Move your code to a pre-initializer ` +
        `that runs before "freeze-valid-blocks".`
    );
    return;
  }

  if (!BlockClass?.blockName) {
    raiseValidationError(
      `Block class "${BlockClass?.name}" must be decorated with @block to be registered.`
    );
    return;
  }

  if (blockRegistry.has(BlockClass.blockName)) {
    raiseValidationError(
      `Block "${BlockClass.blockName}" is already registered.`
    );
    return;
  }

  blockRegistry.set(BlockClass.blockName, BlockClass);
}

/**
 * Freezes the block registry, preventing further registrations.
 * Called by the `freeze-valid-blocks` initializer.
 *
 * After freezing:
 * - `_registerBlock()` will throw an error
 * - `api.renderBlocks()` can use registered blocks
 */
export function _freezeBlockRegistry() {
  registryFrozen = true;
}

/**
 * Returns whether the block registry is frozen.
 *
 * @returns {boolean}
 */
export function isBlockRegistryFrozen() {
  return registryFrozen;
}

/**
 * Stores the initial frozen state to allow correct reset after tests.
 * @type {boolean | null}
 */
let testRegistryFrozenState = null;

/**
 * Unfreezes the block registry for testing purposes.
 * Call this before registering blocks in tests.
 * Only available in DEBUG mode.
 */
export function withTestBlockRegistration(callback) {
  if (!DEBUG) {
    return;
  }

  if (testRegistryFrozenState === null) {
    testRegistryFrozenState = registryFrozen;
  }

  registryFrozen = false;
  try {
    callback();
  } finally {
    registryFrozen = testRegistryFrozenState;
  }
}

/**
 * Resets the block registry for testing purposes.
 * Clears all registered blocks and restores the original frozen state.
 * Only available in DEBUG mode.
 */
export function resetBlockRegistryForTesting() {
  if (!DEBUG) {
    return;
  }

  blockRegistry.clear();

  if (testRegistryFrozenState !== null) {
    registryFrozen = testRegistryFrozenState;
    testRegistryFrozenState = null;
  } else {
    registryFrozen = false;
  }
}
