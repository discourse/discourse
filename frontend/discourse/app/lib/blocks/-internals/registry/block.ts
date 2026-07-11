import { DEBUG } from "@glimmer/env";
import { trackedMap } from "@ember/reactive/collections";
import type { BlockMetadata } from "discourse/blocks/types";
import { getBlockMetadata } from "discourse/lib/blocks/-internals/decorator";
import { raiseBlockError } from "discourse/lib/blocks/-internals/error";
import {
  OPTIONAL_MISSING,
  type OptionalMissingMarker,
  parseBlockReference,
} from "discourse/lib/blocks/-internals/patterns";
import type {
  BlockClass,
  BlockFactory,
  BlockRegistryEntry,
} from "discourse/lib/blocks/-internals/types";
import { isTesting } from "discourse/lib/environment";
import {
  assertNotDuplicate,
  assertRegistryNotFrozen,
  createTestRegistrationWrapper,
  validateNamePattern,
  validateSourceNamespace,
} from "./helpers";

/*
 * Registry State
 */

/**
 * Registry of block components registered via `api.registerBlock()`.
 * Maps block names to their component classes or factory functions.
 */
const blockRegistry = new Map<string, BlockRegistryEntry>();

/**
 * Cache for resolved factory functions.
 * Once a factory is resolved, the result is stored here to avoid re-resolving.
 *
 * This is a tracked map so that components calling `tryResolveBlock()` will
 * automatically re-render when a factory they depend on finishes resolving.
 * The tracked map tracks per-key, so only components waiting on specific blocks
 * are invalidated.
 */
const resolvedFactoryCache = trackedMap<string, BlockClass>();

/** Tracks in-flight resolution promises to prevent duplicate concurrent attempts. */
const pendingResolutions = new Map<string, Promise<BlockClass | undefined>>();

/** Caches failed resolution attempts to prevent infinite retry loops. */
const failedResolutions = new Set<string>();

/** Whether the block registry is frozen (no new registrations allowed). */
let registryFrozen = false;

/** Stores the initial frozen state to allow correct reset after tests. */
let testRegistryFrozenState: boolean | null = null;

/*
 * Public Functions
 */

/** Returns whether the block registry is frozen. */
export function isBlockRegistryFrozen(): boolean {
  return registryFrozen;
}

/**
 * Checks if a block is registered (by name or class reference).
 *
 * This is a synchronous check that does not resolve factory functions.
 * Use this to verify a block exists before attempting resolution.
 *
 * @param nameOrClass - Block name string or BlockClass.
 * @returns True if the block is registered.
 */
export function hasBlock(nameOrClass: string | BlockClass) {
  if (typeof nameOrClass === "string") {
    return blockRegistry.has(nameOrClass);
  }
  const metadata: BlockMetadata | null = getBlockMetadata(nameOrClass);
  const blockName = metadata?.blockName;
  return blockName && blockRegistry.has(blockName);
}

/**
 * Returns the registry entry for a block (class or factory).
 *
 * @param name - The block name.
 * @returns The registry entry, or undefined if not found.
 */
export function getBlockEntry(name: string): BlockRegistryEntry | undefined {
  return blockRegistry.get(name);
}

/**
 * Returns all block entries with their names as [name, entry] pairs.
 * Used by Blocks service for listing and introspection.
 *
 * @returns Array of [name, entry] pairs.
 */
export function getAllBlockEntries(): Array<[string, BlockRegistryEntry]> {
  return Array.from(blockRegistry.entries());
}

/**
 * Checks if a block is registered and fully resolved (not a pending factory).
 *
 * @param name - The block name to check.
 * @returns True if registered and resolved.
 */
export function isBlockResolved(name: string): boolean {
  if (!blockRegistry.has(name)) {
    return false;
  }
  const entry = blockRegistry.get(name);
  return !isBlockFactory(entry);
}

/**
 * Checks if a registry entry is a factory function (not a resolved class).
 *
 * Factory functions are plain functions not registered in the block metadata WeakMap.
 * BlockClasses are tracked by the `@block` decorator.
 *
 * @param entry - The registry entry to check.
 * @returns True if the entry is a factory function.
 */
export function isBlockFactory(
  entry: BlockRegistryEntry | undefined
): entry is BlockFactory {
  return typeof entry === "function" && !getBlockMetadata(entry);
}

/**
 * Resolves a block reference (string name or class) to a BlockClass.
 *
 * - If given a BlockClass, returns it directly.
 * - If given a string, looks up in registry and resolves factory if needed.
 * - Caches resolved factories to avoid re-resolving.
 *
 * @param nameOrClass - Block name string or BlockClass.
 * @returns The resolved block class, or undefined if resolution previously failed.
 * @throws If block not registered or factory resolution fails on first attempt.
 *
 * @example
 * ```javascript
 * const BlockClass = await resolveBlock("hero-banner");
 * const BlockClass = await resolveBlock(HeroBanner); // Returns directly
 * ```
 */
export async function resolveBlock(
  nameOrClass: string | BlockClass
): Promise<BlockClass | undefined> {
  if (typeof nameOrClass !== "string") {
    if (!getBlockMetadata(nameOrClass)) {
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

  // Guaranteed to be set by the `.has()` check above.
  const entry = blockRegistry.get(name)!;

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
 * @param blockRef - Block reference (string name or class). String names may
 *   include a trailing "?" to mark the block as optional.
 * @returns The BlockClass if found and resolved; an optional-missing marker if
 *   the block is optional and not registered; or `null` if the block is not
 *   registered (non-optional) or is a factory awaiting resolution.
 */
export function tryResolveBlock(
  blockRef: string | BlockClass
): BlockClass | OptionalMissingMarker | null {
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

  // Guaranteed to be set by the `.has()` check above.
  const entry = blockRegistry.get(blockName)!;

  if (!isBlockFactory(entry)) {
    return entry;
  }

  // Trigger async resolution. Returns null for this render cycle - the component
  // will re-render automatically when the factory resolves (tracked via TrackedMap).
  resolveBlock(blockName).catch((error: unknown) => {
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
export function _freezeBlockRegistry(): void {
  registryFrozen = true;
}

/**
 * Registers a block component in the registry.
 * Must be called before any renderBlocks() configuration is registered.
 *
 * The block component must be decorated with `@block`. Block metadata
 * (including `blockName`) is stored in an internal WeakMap and accessed
 * via `getBlockMetadata()`.
 *
 * @param klass - The block component class
 * @throws If called after registry is locked, or if block is invalid
 *
 * @example
 * ```javascript
 * // In a plugin's pre-initializer (plugins/my-plugin/assets/javascripts/pre-initializers/...)
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
export function _registerBlock(klass: BlockClass): void {
  const metadata: BlockMetadata | null = getBlockMetadata(klass);
  const blockName = metadata?.blockName;

  if (
    !assertRegistryNotFrozen({
      frozen: registryFrozen,
      apiMethod: "api.registerBlock()",
      entityType: "Block",
      entityName: blockName || klass.name,
    })
  ) {
    return;
  }

  if (!blockName) {
    raiseBlockError(
      `Block class "${klass.name}" must be decorated with @block to be registered.`
    );
    return;
  }

  if (!validateNamePattern(blockName, "Block")) {
    return;
  }

  if (!validateSourceNamespace({ name: blockName, entityType: "block" })) {
    return;
  }

  if (!assertNotDuplicate(blockRegistry, blockName, "Block")) {
    return;
  }

  blockRegistry.set(blockName, klass);
}

/**
 * Registers a factory function for lazy loading a block.
 *
 * The factory will be called when the block is first needed. It must return
 * a Promise that resolves to a BlockClass (or a module with a default export).
 *
 * @param name - The name to register the block under.
 * @param factory - Factory function returning Promise<BlockClass>.
 * @throws If registry is locked, name is invalid, or factory is not a function.
 *
 * @example
 * ```javascript
 * api.registerBlock("hero-banner", () => import("../blocks/hero-banner"));
 * ```
 *
 * @internal
 */
export function _registerBlockFactory(
  name: string,
  factory: BlockFactory
): void {
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
 * Checks whether a resolved factory value is a module object (with a
 * `.default` export) rather than the block class itself.
 */
function hasDefaultExport(
  value: BlockClass | { default: BlockClass }
): value is { default: BlockClass } {
  return typeof value !== "function";
}

/**
 * Resolves a factory function and caches the result.
 *
 * @param name - The block name.
 * @param factory - The factory function to resolve.
 * @returns The resolved block class.
 * @throws If the factory returns an invalid class or the resolved name doesn't match.
 */
async function resolveFactory(
  name: string,
  factory: BlockFactory
): Promise<BlockClass | undefined> {
  try {
    const result = await factory();
    const resolvedClass: BlockClass = hasDefaultExport(result)
      ? result.default
      : result;
    const resolvedBlockName = getBlockMetadata(resolvedClass)?.blockName;

    if (!resolvedBlockName) {
      raiseBlockError(
        `Block factory for "${name}" did not return a valid @block-decorated class.`
      );
    }

    if (resolvedBlockName !== name) {
      raiseBlockError(
        `Block factory registered as "${name}" resolved to a block with ` +
          `blockName "${resolvedBlockName}". The registered name must match ` +
          `the block's @block decorator name.`
      );
    }

    resolvedFactoryCache.set(name, resolvedClass);
    blockRegistry.set(name, resolvedClass);

    return resolvedClass;
  } catch (error: unknown) {
    failedResolutions.add(name);

    // Thrown errors are always `Error`-like: either a rethrown `BlockError` or
    // a factory/import failure. Cast to read `.name`/`.message` without
    // widening the catch signature to `any`.
    const err = error as Error;

    if (err.name === "BlockError") {
      throw err;
    }
    raiseBlockError(
      `Failed to resolve block factory for "${name}": ${err.message}`
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
export function _resetBlockRegistryState(): void {
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
