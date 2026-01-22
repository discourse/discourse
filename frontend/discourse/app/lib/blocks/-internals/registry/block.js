// @ts-check
import { DEBUG } from "@glimmer/env";
import { TrackedMap } from "@ember-compat/tracked-built-ins";
import { raiseBlockError } from "discourse/lib/blocks/-internals/error";
import {
  OPTIONAL_MISSING,
  parseBlockReference,
} from "discourse/lib/blocks/-internals/patterns";
import { isTesting } from "discourse/lib/environment";
import {
  assertNotDuplicate,
  assertRegistryNotFrozen,
  createTestRegistrationWrapper,
  validateNamePattern,
  validateSourceNamespace,
} from "./helpers";

/**
 * A block class decorated with `@block`.
 *
 * @typedef {typeof import("@glimmer/component").default & {
 *   blockName: string,
 *   blockShortName: string,
 *   blockNamespace: string|null,
 *   blockType: "core"|"plugin"|"theme",
 *   blockMetadata: BlockMetadata
 * }} BlockClass
 */

/**
 * Metadata object containing block configuration set by the `@block` decorator.
 * Includes args schema, container settings, validation, and outlet restrictions.
 *
 * @typedef {{
 *   description: string,
 *   container: boolean,
 *   containerClassNames: string|Array<string>|Function|null,
 *   args: Object|null,
 *   childArgs: Object|null,
 *   constraints: Object|null,
 *   validate: Function|null,
 *   allowedOutlets: ReadonlyArray<string>|null,
 *   deniedOutlets: ReadonlyArray<string>|null
 * }} BlockMetadata
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

/*
 * Registry State
 */

/**
 * Registry of block components registered via `api.registerBlock()`.
 * Maps block names to their component classes or factory functions.
 *
 * @type {Map<string, BlockRegistryEntry>}
 */
const blockRegistry = new Map();

/**
 * Cache for resolved factory functions.
 * Once a factory is resolved, the result is stored here to avoid re-resolving.
 *
 * This is a TrackedMap so that components calling `tryResolveBlock()` will
 * automatically re-render when a factory they depend on finishes resolving.
 * TrackedMap tracks per-key, so only components waiting on specific blocks
 * are invalidated.
 *
 * @type {TrackedMap<string, BlockClass>}
 */
const resolvedFactoryCache = new TrackedMap();

/**
 * Tracks in-flight resolution promises to prevent duplicate concurrent attempts.
 *
 * @type {Map<string, Promise<BlockClass|undefined>>}
 */
const pendingResolutions = new Map();

/**
 * Caches failed resolution attempts to prevent infinite retry loops.
 *
 * @type {Set<string>}
 */
const failedResolutions = new Set();

/**
 * Whether the block registry is frozen (no new registrations allowed).
 */
let registryFrozen = false;

/**
 * Stores the initial frozen state to allow correct reset after tests.
 * @type {boolean | null}
 */
let testRegistryFrozenState = null;

/*
 * Public Functions
 */

/**
 * Returns whether the block registry is frozen.
 *
 * @returns {boolean}
 */
export function isBlockRegistryFrozen() {
  return registryFrozen;
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
 * Returns the registry entry for a block (class or factory).
 *
 * @param {string} name - The block name.
 * @returns {BlockRegistryEntry | undefined} The registry entry, or undefined if not found.
 */
export function getBlockEntry(name) {
  return blockRegistry.get(name);
}

/**
 * Returns all block entries with their names as [name, entry] pairs.
 * Used by Blocks service for listing and introspection.
 *
 * @returns {Array<[string, BlockRegistryEntry]>} Array of [name, entry] pairs.
 */
export function getAllBlockEntries() {
  return Array.from(blockRegistry.entries());
}

/**
 * Checks if a block is registered and fully resolved (not a pending factory).
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
 * Checks if a registry entry is a factory function (not a resolved class).
 *
 * Factory functions are plain functions without a `blockName` property.
 * BlockClasses have `blockName` set by the `@block` decorator.
 *
 * @param {BlockRegistryEntry} entry - The registry entry to check.
 * @returns {entry is BlockFactory} True if the entry is a factory function.
 */
export function isBlockFactory(entry) {
  // @ts-ignore - blockName exists on BlockClass but not BlockFactory
  return typeof entry === "function" && !entry.blockName;
}

/**
 * Resolves a block reference (string name or class) to a BlockClass.
 *
 * - If given a BlockClass, returns it directly.
 * - If given a string, looks up in registry and resolves factory if needed.
 * - Caches resolved factories to avoid re-resolving.
 *
 * @param {string | BlockClass} nameOrClass - Block name string or BlockClass.
 * @returns {Promise<BlockClass|undefined>} The resolved block class, or undefined if resolution previously failed.
 * @throws {Error} If block not registered or factory resolution fails on first attempt.
 *
 * @example
 * ```javascript
 * const BlockClass = await resolveBlock("hero-banner");
 * const BlockClass = await resolveBlock(HeroBanner); // Returns directly
 * ```
 */
export async function resolveBlock(nameOrClass) {
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

  if (resolvedFactoryCache.has(name)) {
    return resolvedFactoryCache.get(name);
  }

  if (failedResolutions.has(name)) {
    return undefined;
  }

  if (pendingResolutions.has(name)) {
    return pendingResolutions.get(name);
  }

  if (!blockRegistry.has(name)) {
    raiseBlockError(
      `Block "${name}" is not registered. ` +
        `Use api.registerBlock() in a pre-initializer before any renderBlocks() configuration.`
    );
  }

  const entry = blockRegistry.get(name);

  if (!isBlockFactory(entry)) {
    return entry;
  }

  const resolutionPromise = resolveFactory(name, entry);
  pendingResolutions.set(name, resolutionPromise);
  return resolutionPromise;
}

/**
 * Attempts to resolve a block reference to a BlockClass synchronously.
 *
 * If the block is already resolved, returns the BlockClass immediately.
 * If the block is a factory that hasn't resolved yet, triggers async resolution
 * and returns null. The calling component will automatically re-render when the
 * factory resolves.
 *
 * @param {string | BlockClass} blockRef - Block reference (string name or class).
 *   String names may include a trailing "?" to mark the block as optional.
 * @returns {BlockClass | { optionalMissing: symbol, name: string } | null}
 *   - The BlockClass if found and resolved
 *   - An object with `optionalMissing` marker if the block is optional and not registered
 *   - null if the block is not registered (non-optional) or is a pending factory
 */
export function tryResolveBlock(blockRef) {
  if (typeof blockRef !== "string") {
    return blockRef;
  }

  const { name: blockName, optional } = parseBlockReference(blockRef);

  // Check cache first - ALWAYS call .get() to establish tracking dependency.
  // TrackedMap establishes tracking even when key doesn't exist (returns undefined).
  // This ensures component re-renders when factory resolves and calls .set().
  const cachedClass = resolvedFactoryCache.get(blockName);
  if (cachedClass) {
    return cachedClass;
  }

  if (!blockRegistry.has(blockName)) {
    if (optional) {
      return { optionalMissing: OPTIONAL_MISSING, name: blockName };
    }
    // eslint-disable-next-line no-console
    console.error(`[Blocks] Block "${blockName}" is not registered.`);
    return null;
  }

  const entry = blockRegistry.get(blockName);

  if (!isBlockFactory(entry)) {
    return entry;
  }

  // Trigger async resolution. Returns null for this render cycle - the component
  // will re-render automatically when the factory resolves (tracked via TrackedMap).
  resolveBlock(blockName).catch((error) => {
    // TODO (blocks-api) Consider returning an error marker and rendering an error
    // placeholder component for admin visibility, rather than silently returning null.
    document.dispatchEvent(
      new CustomEvent("discourse-error", {
        detail: { messageKey: "broken_block_factory_alert", error },
      })
    );
  });

  return null;
}

/*
 * Internal Functions
 */

/**
 * Freezes the registry, preventing further registrations.
 * Called by the "freeze-block-registry" initializer during app boot.
 *
 * @internal
 */
export function _freezeBlockRegistry() {
  registryFrozen = true;
}

/**
 * Registers a block component in the registry.
 * Must be called before any renderBlocks() configuration is registered.
 *
 * The block component must be decorated with `@block` and have a
 * `blockName` static property (set by the decorator).
 *
 * @param {BlockClass} BlockClass - The block component class
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
  if (
    !assertRegistryNotFrozen({
      frozen: registryFrozen,
      apiMethod: "api.registerBlock()",
      entityType: "Block",
      entityName: BlockClass?.blockName || BlockClass?.name,
    })
  ) {
    return;
  }

  if (!BlockClass?.blockName) {
    raiseBlockError(
      `Block class "${BlockClass?.name}" must be decorated with @block to be registered.`
    );
    return;
  }

  const blockName = BlockClass.blockName;

  if (!validateNamePattern(blockName, "Block")) {
    return;
  }

  if (!validateSourceNamespace({ name: blockName, entityType: "block" })) {
    return;
  }

  if (!assertNotDuplicate(blockRegistry, blockName, "Block")) {
    return;
  }

  blockRegistry.set(blockName, BlockClass);
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
 * ```
 *
 * @internal
 */
export function _registerBlockFactory(name, factory) {
  if (
    !assertRegistryNotFrozen({
      frozen: registryFrozen,
      apiMethod: "api.registerBlock()",
      entityType: "Block",
      entityName: name,
    })
  ) {
    return;
  }

  if (!validateNamePattern(name, "Block")) {
    return;
  }

  if (typeof factory !== "function") {
    raiseBlockError(
      `Block factory for "${name}" must be a function that returns a Promise<BlockClass>.`
    );
    return;
  }

  if (!validateSourceNamespace({ name, entityType: "block" })) {
    return;
  }

  if (!assertNotDuplicate(blockRegistry, name, "Block")) {
    return;
  }

  blockRegistry.set(name, factory);
}

/**
 * Resolves a factory function and caches the result.
 *
 * @param {string} name - The block name.
 * @param {BlockFactory} factory - The factory function to resolve.
 * @returns {Promise<BlockClass|undefined>} The resolved block class, or undefined on failure.
 */
async function resolveFactory(name, factory) {
  try {
    const result = await factory();
    // @ts-ignore - result may be a module with .default or direct BlockClass
    const BlockClass = result?.default ?? result;

    if (!BlockClass?.blockName) {
      raiseBlockError(
        `Block factory for "${name}" did not return a valid @block-decorated class.`
      );
    }

    if (BlockClass.blockName !== name) {
      raiseBlockError(
        `Block factory registered as "${name}" resolved to a block with ` +
          `blockName "${BlockClass.blockName}". The registered name must match ` +
          `the block's @block decorator name.`
      );
    }

    resolvedFactoryCache.set(name, BlockClass);
    blockRegistry.set(name, BlockClass);

    return BlockClass;
  } catch (error) {
    failedResolutions.add(name);

    if (error.name === "BlockError") {
      throw error;
    }
    raiseBlockError(
      `Failed to resolve block factory for "${name}": ${error.message}`
    );
    return undefined;
  } finally {
    pendingResolutions.delete(name);
  }
}

/*
 * Test Utilities
 */

/**
 * Temporarily unfreezes the block registry for testing.
 *
 * USE ONLY FOR TESTING PURPOSES.
 *
 * @param {Function} callback - Function to execute with unfrozen registry.
 */
export const withTestBlockRegistration = createTestRegistrationWrapper({
  getFrozen: () => registryFrozen,
  setFrozen: (value) => {
    registryFrozen = value;
  },
  getSavedState: () => testRegistryFrozenState,
  setSavedState: (value) => {
    testRegistryFrozenState = value;
  },
  name: "withTestBlockRegistration",
});

/**
 * Resets the block registry state for testing.
 *
 * USE ONLY FOR TESTING PURPOSES.
 *
 * @internal Called by `resetBlockRegistryForTesting`, not meant for direct use.
 */
export function _resetBlockRegistryState() {
  // allows tree-shaking in production builds
  if (!DEBUG) {
    return;
  }
  if (!isTesting()) {
    throw new Error("_resetBlockRegistryState can only be used in tests.");
  }
  blockRegistry.clear();
  resolvedFactoryCache.clear();
  pendingResolutions.clear();
  failedResolutions.clear();
  registryFrozen = false;
  testRegistryFrozenState = null;
}
