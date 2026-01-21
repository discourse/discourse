// @ts-check
import { DEBUG } from "@glimmer/env";
import { isDecoratedCondition } from "discourse/blocks/conditions/decorator";
import { raiseBlockError } from "discourse/lib/blocks/core/error";
import {
  OPTIONAL_MISSING,
  parseBlockName,
  parseBlockReference,
  VALID_NAMESPACED_BLOCK_PATTERN,
} from "discourse/lib/blocks/core/patterns";
import { isTesting } from "discourse/lib/environment";
import { BLOCK_OUTLETS } from "discourse/lib/registry/block-outlets";
import identifySource from "discourse/lib/source-identifier";

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
 * NOT EXPORTED: External code must use accessor functions (hasBlock, getBlockEntry,
 * getAllBlockEntries) to prevent bypassing the frozen registry check.
 *
 * @type {Map<string, BlockRegistryEntry>}
 */
const blockRegistry = new Map();

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
 * Whether the block registry is frozen (no new registrations allowed).
 * Frozen by the "freeze-block-registry" initializer during app boot.
 */
let registryFrozen = false;

/**
 * Override for source identifier in tests.
 * @type {string|null|undefined}
 */
let testSourceIdentifier;

/**
 * Sets a test override for the source identifier.
 *
 * USE ONLY FOR TESTING PURPOSES.
 *
 * @param {string|null} sourceId - Source identifier to use, or null to clear.
 */
export function _setTestSourceIdentifier(sourceId) {
  if (!isTesting()) {
    throw new Error("Use `_setTestSourceIdentifier` only in tests.");
  }
  testSourceIdentifier = sourceId;
}

/**
 * Gets a unique identifier for the current source from the call stack.
 * Returns null for core code (no theme or plugin detected).
 *
 * @returns {string|null} Source identifier like "theme:Tactile" or "plugin:chat"
 */
function getSourceIdentifier() {
  // Allow test override
  if (DEBUG && testSourceIdentifier !== undefined) {
    return testSourceIdentifier;
  }

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
 * Validates that a block or outlet name follows namespace requirements for themes and plugins.
 *
 * This helper enforces the following rules:
 * - Themes must use `theme:namespace:name` format
 * - Plugins must use `namespace:name` format
 * - Optionally enforces that each source uses a consistent namespace across all registrations
 *
 * @param {Object} options - Validation options.
 * @param {string} options.name - The name being registered.
 * @param {"block"|"outlet"} options.entityType - Type of entity for error messages.
 * @param {boolean} [options.enforceConsistency=true] - Whether to enforce single namespace per source.
 * @returns {boolean} True if validation passes, false if it failed (error was raised).
 */
function validateSourceNamespace({
  name,
  entityType,
  enforceConsistency = true,
}) {
  const sourceId = getSourceIdentifier();
  if (!sourceId) {
    return true; // Core code - no namespace validation needed
  }

  const namespacePrefix = getNamespacePrefix(name);
  const entityPlural = entityType === "block" ? "blocks" : "outlets";
  const entityCapitalized =
    entityType.charAt(0).toUpperCase() + entityType.slice(1);

  // Themes must use theme:namespace:name format
  if (sourceId.startsWith("theme:") && !namespacePrefix?.startsWith("theme:")) {
    raiseBlockError(
      `Theme ${entityPlural} must use the "theme:namespace:${entityType}-name" format. ` +
        `${entityCapitalized} "${name}" should be renamed to "theme:<your-theme>:${name}".`
    );
    return false;
  }

  // Plugins must use namespace:name format
  if (sourceId.startsWith("plugin:") && !namespacePrefix) {
    const pluginName = sourceId.replace("plugin:", "");
    raiseBlockError(
      `Plugin ${entityPlural} must use the "namespace:${entityType}-name" format. ` +
        `${entityCapitalized} "${name}" should be renamed to "${pluginName}:${name}".`
    );
    return false;
  }

  // Enforce single namespace per source (only for blocks, not outlets)
  if (enforceConsistency) {
    const existingNamespace = sourceNamespaceMap.get(sourceId);
    if (
      existingNamespace !== undefined &&
      existingNamespace !== namespacePrefix
    ) {
      raiseBlockError(
        `${entityCapitalized} "${name}" uses namespace "${namespacePrefix ?? "(core)"}" but ` +
          `${sourceId} already registered ${entityPlural} with namespace "${existingNamespace ?? "(core)"}". ` +
          `Each theme/plugin must use a single consistent namespace.`
      );
      return false;
    }
    sourceNamespaceMap.set(sourceId, namespacePrefix);
  }

  return true;
}

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
 * Returns whether the block registry is frozen.
 *
 * @returns {boolean}
 */
export function isBlockRegistryFrozen() {
  return registryFrozen;
}

// Backwards compatibility aliases
export const _lockBlockRegistry = _freezeBlockRegistry;
export const isBlockRegistryLocked = isBlockRegistryFrozen;

/**
 * Registers a block component in the registry.
 * Must be called before any renderBlocks() configuration is registered.
 *
 * The block component must be decorated with `@block` and have:
 * - `blockName` static property (set by the decorator)
 * - `blockMetadata` static property (set by the decorator)
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
  if (registryFrozen) {
    raiseBlockError(
      `api.registerBlock() was called after the block registry was frozen. ` +
        `Move your code to a pre-initializer that runs before "freeze-block-registry". ` +
        `Block: "${BlockClass?.blockName || BlockClass?.name}"`
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

  // Validate namespace requirements for themes and plugins
  if (!validateSourceNamespace({ name: blockName, entityType: "block" })) {
    return;
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
 * @returns {entry is BlockFactory} True if the entry is a factory function.
 */
export function isBlockFactory(entry) {
  // @ts-ignore - blockName exists on BlockClass but not BlockFactory (intentional type narrowing)
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
  if (registryFrozen) {
    raiseBlockError(
      `api.registerBlock() was called after the block registry was frozen. ` +
        `Move your code to a pre-initializer that runs before "freeze-block-registry". ` +
        `Block: "${name}"`
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

  // Validate namespace requirements for themes and plugins
  if (!validateSourceNamespace({ name, entityType: "block" })) {
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
    // @ts-ignore - result may be a module with .default or direct BlockClass
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
 * Stores the initial frozen state to allow correct reset after tests.
 * @type {boolean | null}
 */
let testRegistryFrozenState = null;

/*
 * Outlet Registration
 */

/**
 * Registry of custom block outlets registered by plugins and themes.
 * Maps outlet names to their metadata.
 *
 * NOT EXPORTED: External code must use accessor functions (getAllOutlets,
 * isValidOutlet, getCustomOutlet) to prevent bypassing the frozen registry check.
 *
 * @type {Map<string, { name: string, description?: string }>}
 */
const customOutletRegistry = new Map();

/**
 * Whether the outlet registry is frozen (no new registrations allowed).
 * Frozen by the "freeze-block-registry" initializer during app boot.
 */
let outletRegistryFrozen = false;

/**
 * Temporarily unfreezes the block registry for testing purposes.
 * Call this before registering blocks in tests.
 *
 * USE ONLY FOR TESTING PURPOSES.
 *
 * @param {Function} callback - Function to execute with unfrozen registry.
 */
export function withTestBlockRegistration(callback) {
  if (!isTesting()) {
    throw new Error("Use `withTestBlockRegistration` only in tests.");
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
 * Stores the initial frozen state for condition registry to allow correct reset after tests.
 * @type {boolean | null}
 */
let testConditionRegistryFrozenState = null;

/**
 * Temporarily unfreezes the condition type registry for testing purposes.
 * Call this before registering condition types in tests.
 *
 * USE ONLY FOR TESTING PURPOSES.
 *
 * @param {Function} callback - Function to execute with unfrozen registry.
 *
 * @example
 * ```javascript
 * withTestConditionRegistration(() => {
 *   _registerConditionType(MyTestCondition);
 * });
 * ```
 */
export function withTestConditionRegistration(callback) {
  if (!isTesting()) {
    throw new Error("Use `withTestConditionRegistration` only in tests.");
  }

  if (testConditionRegistryFrozenState === null) {
    testConditionRegistryFrozenState = conditionTypeRegistryFrozen;
  }

  conditionTypeRegistryFrozen = false;
  try {
    callback();
  } finally {
    conditionTypeRegistryFrozen = testConditionRegistryFrozenState;
  }
}

/**
 * Resets the block registry for testing purposes.
 * Clears all registered blocks, outlets, and condition types.
 * Restores the original frozen state.
 *
 * USE ONLY FOR TESTING PURPOSES.
 */
export function resetBlockRegistryForTesting() {
  if (!isTesting()) {
    throw new Error("Use `resetBlockRegistryForTesting` only in tests.");
  }

  blockRegistry.clear();
  resolvedFactoryCache.clear();
  pendingResolutions.clear();
  failedResolutions.clear();
  sourceNamespaceMap.clear();
  testSourceIdentifier = undefined;

  // Always reset frozen state to false for testing.
  // The saved test state is only for use during a single test, not between tests.
  registryFrozen = false;
  testRegistryFrozenState = null;

  // Reset outlet registry
  customOutletRegistry.clear();
  outletRegistryFrozen = false;

  // Reset condition type registry
  conditionTypeRegistry.clear();
  conditionTypeRegistryFrozen = false;
  testConditionRegistryFrozenState = null;
}

/**
 * Registers a custom block outlet.
 *
 * Custom outlets follow the same naming conventions as blocks:
 * - Core outlets: `outlet-name` (kebab-case)
 * - Plugin outlets: `namespace:outlet-name`
 * - Theme outlets: `theme:namespace:outlet-name`
 *
 * @param {string} outletName - The outlet name (must follow naming conventions).
 * @param {Object} [options] - Outlet options.
 * @param {string} [options.description] - Human-readable description.
 *
 * @internal
 */
export function _registerOutlet(outletName, options = {}) {
  if (outletRegistryFrozen) {
    raiseBlockError(
      `api.registerBlockOutlet() was called after the outlet registry was frozen. ` +
        `Move your code to a pre-initializer that runs before "freeze-block-registry". ` +
        `Outlet: "${outletName}"`
    );
    return;
  }

  // Validate name format (same pattern as blocks)
  if (!VALID_NAMESPACED_BLOCK_PATTERN.test(outletName)) {
    raiseBlockError(
      `Outlet name "${outletName}" is invalid. ` +
        `Valid formats: "outlet-name" (core), "plugin:outlet-name" (plugin), ` +
        `"theme:namespace:outlet-name" (theme).`
    );
    return;
  }

  // Check for duplicates against both core and custom outlets
  if (BLOCK_OUTLETS.includes(outletName)) {
    raiseBlockError(
      `Outlet "${outletName}" is already registered as a core outlet.`
    );
    return;
  }

  if (customOutletRegistry.has(outletName)) {
    raiseBlockError(`Outlet "${outletName}" is already registered.`);
    return;
  }

  // Validate namespace requirements for themes and plugins (no consistency check for outlets)
  if (
    !validateSourceNamespace({
      name: outletName,
      entityType: "outlet",
      enforceConsistency: false,
    })
  ) {
    return;
  }

  customOutletRegistry.set(outletName, {
    name: outletName,
    description: options.description,
  });
}

/**
 * Freezes the outlet registry, preventing further registrations.
 * Called by the "freeze-block-registry" initializer during app boot.
 *
 * @internal
 */
export function _freezeOutletRegistry() {
  outletRegistryFrozen = true;
}

/**
 * Returns whether the outlet registry is frozen.
 *
 * @returns {boolean}
 */
export function isOutletRegistryFrozen() {
  return outletRegistryFrozen;
}

/**
 * Returns all valid outlet names (both core and custom).
 *
 * @returns {string[]} Array of all outlet names.
 */
export function getAllOutlets() {
  return [...BLOCK_OUTLETS, ...customOutletRegistry.keys()];
}

/**
 * Checks if an outlet name is valid (registered as core or custom).
 *
 * @param {string} name - The outlet name to check.
 * @returns {boolean} True if the outlet is registered.
 */
export function isValidOutlet(name) {
  return BLOCK_OUTLETS.includes(name) || customOutletRegistry.has(name);
}

/**
 * Gets metadata for a custom outlet.
 *
 * @param {string} name - The outlet name.
 * @returns {{ name: string, description?: string } | undefined} Outlet metadata or undefined.
 */
export function getCustomOutlet(name) {
  return customOutletRegistry.get(name);
}

/*
 * Condition Type Registration
 */

/**
 * Registry of condition type classes registered by core, plugins, and themes.
 * Maps condition type names to their class constructors.
 *
 * Unlike blocks which store component classes, conditions are stored as classes
 * and instantiated by the Blocks service when first needed. This allows the
 * service to set the owner for dependency injection.
 *
 * NOT EXPORTED: External code must use accessor functions (hasConditionType,
 * getAllConditionTypeEntries) to prevent bypassing the frozen registry check.
 *
 * @type {Map<string, typeof import("discourse/blocks/conditions").BlockCondition>}
 */
const conditionTypeRegistry = new Map();

/**
 * Whether the condition type registry is frozen (no new registrations allowed).
 * Frozen by the "freeze-block-registry" initializer during app boot.
 */
let conditionTypeRegistryFrozen = false;

/**
 * Registers a condition type class in the registry.
 * Must be called before the registry is frozen by the "freeze-block-registry" initializer.
 *
 * The condition class must be decorated with `@blockCondition` and have:
 * - `type` static property (set by the decorator)
 * - `validArgKeys` static property (set by the decorator)
 *
 * @param {typeof import("discourse/blocks/conditions").BlockCondition} ConditionClass - The condition class to register.
 *
 * @example
 * ```javascript
 * import { withPluginApi } from "discourse/lib/plugin-api";
 * import MyCondition from "../conditions/my-condition";
 *
 * export default {
 *   initialize() {
 *     withPluginApi("1.0", (api) => {
 *       api.registerBlockConditionType(MyCondition);
 *     });
 *   },
 * };
 * ```
 *
 * @internal
 */
export function _registerConditionType(ConditionClass) {
  if (conditionTypeRegistryFrozen) {
    raiseBlockError(
      `api.registerBlockConditionType() was called after the condition type registry was frozen. ` +
        `Move your code to a pre-initializer that runs before "freeze-block-registry". ` +
        `Condition: "${ConditionClass?.type || ConditionClass?.name}"`
    );
    return;
  }

  // Ensure the class was created by the @blockCondition decorator
  if (!isDecoratedCondition(ConditionClass)) {
    raiseBlockError(
      `${ConditionClass.name} must use the @blockCondition decorator. ` +
        `Manual inheritance from BlockCondition is not allowed.`
    );
    return;
  }

  const type = ConditionClass.type;

  if (conditionTypeRegistry.has(type)) {
    raiseBlockError(`Condition type "${type}" is already registered`);
    return;
  }

  conditionTypeRegistry.set(type, ConditionClass);
}

/**
 * Freezes the condition type registry, preventing further registrations.
 * Called by the "freeze-block-registry" initializer during app boot.
 *
 * @internal
 */
export function _freezeConditionTypeRegistry() {
  conditionTypeRegistryFrozen = true;
}

/**
 * Returns whether the condition type registry is frozen.
 *
 * @returns {boolean}
 */
export function isConditionTypeRegistryFrozen() {
  return conditionTypeRegistryFrozen;
}

/**
 * Checks if a condition type is registered.
 *
 * @param {string} type - The condition type name.
 * @returns {boolean}
 */
export function hasConditionType(type) {
  return conditionTypeRegistry.has(type);
}

/**
 * Returns all condition type entries as [type, ConditionClass] pairs.
 * Used by Blocks service for lazy initialization.
 *
 * @returns {Array<[string, typeof import("discourse/blocks/conditions").BlockCondition]>}
 */
export function getAllConditionTypeEntries() {
  return Array.from(conditionTypeRegistry.entries());
}
