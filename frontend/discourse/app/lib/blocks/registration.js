import { DEBUG } from "@glimmer/env";
import { raiseBlockError } from "discourse/lib/blocks/error";
import {
  OPTIONAL_MISSING,
  parseBlockName,
  parseBlockReference,
  VALID_BLOCK_NAME_PATTERN,
  VALID_NAMESPACED_BLOCK_PATTERN,
} from "discourse/lib/blocks/patterns";
import identifySource from "discourse/lib/source-identifier";

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
 * Tracks in-flight resolution promises to prevent duplicate concurrent attempts.
 * When a factory is being resolved, the promise is stored here so subsequent
 * callers can await the same promise instead of triggering a new resolution.
 *
 * @type {Map<string, Promise<BlockClass|undefined>>}
 */
const pendingResolutions = new Map();

/**
 * Caches failed resolution attempts to prevent infinite retry loops.
 * When a factory fails to resolve, the block name is added here to prevent
 * subsequent render cycles from triggering new resolution attempts.
 *
 * @type {Set<string>}
 */
const failedResolutions = new Set();

/**
 * Tracks which namespace each source (theme/plugin) has used.
 * Enforces that each source can only register blocks with a single namespace.
 *
 * Key: source identifier (e.g., "theme:Tactile Theme" or "plugin:chat")
 * Value: the namespace prefix used (e.g., "theme:tactile" or "chat")
 *
 * @type {Map<string, string|null>}
 */
const sourceNamespaceMap = new Map();

/**
 * Whether the block registry is locked (no new registrations allowed).
 * Gets locked when the first renderBlocks() config is registered.
 */
let registryLocked = false;

/**
 * Gets a unique identifier for the current source from the call stack.
 * Returns null for core code (no theme or plugin detected).
 *
 * @returns {string|null} Source identifier like "theme:Tactile" or "plugin:chat"
 */
function getSourceIdentifier() {
  const source = identifySource();
  if (!source) {
    return null;
  }
  if (source.type === "theme") {
    return `theme:${source.name}`;
  }
  if (source.type === "plugin") {
    return `plugin:${source.name}`;
  }
  return null;
}

/**
 * Extracts the namespace prefix from a block name.
 *
 * @param {string} blockName - The full block name.
 * @returns {string|null} The namespace prefix, or null for core blocks.
 *
 * @example
 * getNamespacePrefix("theme:tactile:banner") // => "theme:tactile"
 * getNamespacePrefix("chat:widget")          // => "chat"
 * getNamespacePrefix("group")                // => null (core)
 */
function getNamespacePrefix(blockName) {
  const parsed = parseBlockName(blockName);
  if (!parsed) {
    return null;
  }
  if (parsed.type === "theme") {
    return `theme:${parsed.namespace}`;
  }
  if (parsed.type === "plugin") {
    return parsed.namespace;
  }
  return null; // core
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

  const blockName = BlockClass.blockName;

  // Validate full namespaced block name format
  if (!VALID_NAMESPACED_BLOCK_PATTERN.test(blockName)) {
    raiseBlockError(
      `Block name "${blockName}" is invalid. ` +
        `Valid formats: "block-name" (core), "plugin:block-name" (plugin), ` +
        `"theme:namespace:block-name" (theme).`
    );
    return;
  }

  // Enforce single namespace per source (theme/plugin)
  const sourceId = getSourceIdentifier();
  const namespacePrefix = getNamespacePrefix(blockName);

  if (sourceId) {
    const existingNamespace = sourceNamespaceMap.get(sourceId);
    if (
      existingNamespace !== undefined &&
      existingNamespace !== namespacePrefix
    ) {
      raiseBlockError(
        `Block "${blockName}" uses namespace "${namespacePrefix ?? "(core)"}" but ` +
          `${sourceId} already registered blocks with namespace "${existingNamespace ?? "(core)"}". ` +
          `Each theme/plugin must use a single consistent namespace.`
      );
      return;
    }
    sourceNamespaceMap.set(sourceId, namespacePrefix);
  }

  if (blockRegistry.has(blockName)) {
    raiseBlockError(`Block "${blockName}" is already registered.`);
    return;
  }

  blockRegistry.set(blockName, BlockClass);
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

  // Validate full namespaced block name format
  if (!VALID_NAMESPACED_BLOCK_PATTERN.test(name)) {
    raiseBlockError(
      `Block name "${name}" is invalid. ` +
        `Valid formats: "block-name" (core), "plugin:block-name" (plugin), ` +
        `"theme:namespace:block-name" (theme).`
    );
    return;
  }

  if (typeof factory !== "function") {
    raiseBlockError(
      `Block factory for "${name}" must be a function that returns a Promise<BlockClass>.`
    );
    return;
  }

  // Enforce single namespace per source (theme/plugin)
  const sourceId = getSourceIdentifier();
  const namespacePrefix = getNamespacePrefix(name);

  if (sourceId) {
    const existingNamespace = sourceNamespaceMap.get(sourceId);
    if (
      existingNamespace !== undefined &&
      existingNamespace !== namespacePrefix
    ) {
      raiseBlockError(
        `Block "${name}" uses namespace "${namespacePrefix ?? "(core)"}" but ` +
          `${sourceId} already registered blocks with namespace "${existingNamespace ?? "(core)"}". ` +
          `Each theme/plugin must use a single consistent namespace.`
      );
      return;
    }
    sourceNamespaceMap.set(sourceId, namespacePrefix);
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

  // Check if resolution previously failed - don't retry
  if (failedResolutions.has(name)) {
    return undefined;
  }

  // Check if resolution is already in-flight - reuse the same promise
  if (pendingResolutions.has(name)) {
    return pendingResolutions.get(name);
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

  // Track the resolution promise to prevent duplicate concurrent attempts
  const resolutionPromise = resolveFactory(name, entry);
  pendingResolutions.set(name, resolutionPromise);
  return resolutionPromise;
}

/**
 * Resolves a factory function and caches the result.
 * Handles cleanup of pending tracking regardless of success or failure.
 *
 * @param {string} name - The block name.
 * @param {BlockFactory} factory - The factory function to resolve.
 * @returns {Promise<BlockClass|undefined>} The resolved block class, or undefined on failure.
 */
async function resolveFactory(name, factory) {
  try {
    const result = await factory();
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
    // Cache the failure to prevent infinite retry loops
    failedResolutions.add(name);

    if (error.name === "BlockError") {
      throw error;
    }
    raiseBlockError(
      `Failed to resolve block factory for "${name}": ${error.message}`
    );
    // In production, raiseBlockError dispatches an event but doesn't throw.
    // Return undefined explicitly for graceful degradation - callers can
    // handle this by skipping rendering of the block.
    return undefined;
  } finally {
    // Clean up pending tracking once resolution completes (success or failure)
    pendingResolutions.delete(name);
  }
}

/**
 * Synchronously resolves a block reference to a BlockClass.
 *
 * Unlike `resolveBlock`, this function is synchronous and handles the case
 * where a factory function hasn't been resolved yet. If a factory is
 * encountered, it triggers async resolution but returns null for the current
 * render cycle (the component will re-render when the factory resolves).
 *
 * @param {string | BlockClass} blockRef - Block reference (string name or class).
 *   String names may include a trailing "?" to mark the block as optional.
 * @returns {BlockClass | { optionalMissing: symbol, name: string } | null}
 *   - The BlockClass if found and resolved
 *   - An object with `optionalMissing` marker if the block is optional and not registered
 *   - null if the block is not registered (non-optional) or is a pending factory
 */
export function resolveBlockSync(blockRef) {
  // If already a class, return it directly
  if (typeof blockRef !== "string") {
    return blockRef;
  }

  // Parse the block reference to extract name and optional flag
  const { name: blockName, optional } = parseBlockReference(blockRef);

  // Check if block is registered
  if (!blockRegistry.has(blockName)) {
    if (optional) {
      // Return a marker object so callers can distinguish optional missing blocks
      return { optionalMissing: OPTIONAL_MISSING, name: blockName };
    }
    // eslint-disable-next-line no-console
    console.error(`[Blocks] Block "${blockName}" is not registered.`);
    return null;
  }

  const entry = blockRegistry.get(blockName);

  // If not a factory, return the class directly
  if (!isBlockFactory(entry)) {
    return entry;
  }

  // It's a factory that hasn't been resolved yet.
  // Trigger async resolution but return null for this render cycle.
  // The component will re-render when the factory resolves.
  if (!DEBUG) {
    resolveBlock(blockName).catch((error) => {
      // eslint-disable-next-line no-console
      console.error(`[Blocks] Failed to resolve block "${blockName}":`, error);
    });
  }

  return null;
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
  pendingResolutions.clear();
  failedResolutions.clear();
  sourceNamespaceMap.clear();

  if (testRegistryLockedState !== null) {
    registryLocked = testRegistryLockedState;
    testRegistryLockedState = null;
  } else {
    registryLocked = false;
  }
}
