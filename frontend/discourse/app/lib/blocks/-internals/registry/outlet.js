// @ts-check
import { DEBUG } from "@glimmer/env";
import { raiseBlockError } from "discourse/lib/blocks/-internals/error";
import { parseBlockName } from "discourse/lib/blocks/-internals/patterns";
import { isTesting } from "discourse/lib/environment";
import {
  BLOCK_OUTLETS,
  CORE_OUTLET_METADATA,
} from "discourse/lib/registry/block-outlets";
import {
  assertRegistryNotFrozen,
  validateNamePattern,
  validateSourceNamespace,
} from "./helpers";

/**
 * @typedef OutletMetadataEntry
 * @property {string} name - The full outlet identifier (e.g. `"chat:thread-actions"`).
 * @property {string|null} displayName - Human-readable label for display purposes.
 * @property {string|null} description - One-line summary of where the outlet renders.
 * @property {string|null} category - Optional sub-grouping label (free-form, e.g. `"Layout"`).
 * @property {boolean} isCore - True for the 5 outlets baked into core.
 * @property {"core"|"plugin"|"theme"} namespaceType - Derived from the outlet name's namespace prefix.
 */

/*
 * Registry State
 */

/**
 * Registry of custom block outlets registered by plugins and themes.
 * Maps outlet names to their metadata.
 *
 * @type {Map<string, { name: string, displayName?: string, description?: string, category?: string }>}
 */
const customOutletRegistry = new Map();

/**
 * Whether the outlet registry is frozen (no new registrations allowed).
 */
let outletRegistryFrozen = false;

/*
 * Public Functions
 */

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
 * @returns {{ name: string, displayName?: string, description?: string, category?: string } | undefined} Outlet metadata or undefined.
 */
export function getCustomOutlet(name) {
  return customOutletRegistry.get(name);
}

/**
 * Returns the fully-resolved display metadata for any registered outlet
 * (core or custom). Defaults are applied for optional fields so callers
 * don't have to.
 *
 * Defaults:
 * - `displayName` defaults to `name` itself when the registration didn't
 *   set one. Consumers can still apply additional title-casing at display
 *   time.
 * - `description`, `category` default to `null`.
 *
 * @param {string} name - The full outlet name.
 * @returns {OutletMetadataEntry|null} The metadata, or `null` for unregistered names.
 */
export function getOutletMetadata(name) {
  if (CORE_OUTLET_METADATA[name]) {
    const meta = CORE_OUTLET_METADATA[name];
    return {
      name,
      displayName: meta.displayName ?? name,
      description: meta.description ?? null,
      category: meta.category ?? null,
      isCore: true,
      namespaceType: "core",
    };
  }

  const custom = customOutletRegistry.get(name);
  if (custom) {
    const parsed = parseBlockName(name);
    return {
      name,
      displayName: custom.displayName ?? name,
      description: custom.description ?? null,
      category: custom.category ?? null,
      isCore: false,
      namespaceType: parsed?.type ?? "core",
    };
  }

  return null;
}

/**
 * Returns the fully-resolved display metadata for every registered outlet.
 * Used by `services/blocks.js#listOutletsWithMetadata()`.
 *
 * @returns {OutletMetadataEntry[]}
 */
export function getAllOutletsWithMetadata() {
  return getAllOutlets()
    .map((name) => getOutletMetadata(name))
    .filter((m) => m != null);
}

/*
 * Internal Functions
 */

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
 * Registers a custom block outlet.
 *
 * Custom outlets follow the same naming conventions as blocks:
 * - Core outlets: `outlet-name` (kebab-case)
 * - Plugin outlets: `namespace:outlet-name`
 * - Theme outlets: `theme:namespace:outlet-name`
 *
 * @param {string} outletName - The outlet name (must follow naming conventions).
 * @param {Object} [options] - Outlet options.
 * @param {string} [options.displayName] - Human-readable label for display
 *   purposes. Defaults to the outlet name itself.
 * @param {string} [options.description] - One-line summary of where the
 *   outlet renders.
 * @param {string} [options.category] - Optional free-form grouping label
 *   (e.g. `"Layout"`).
 *
 * @internal
 */
export function _registerOutlet(outletName, options = {}) {
  if (
    !assertRegistryNotFrozen({
      frozen: outletRegistryFrozen,
      apiMethod: "api.registerBlockOutlet()",
      entityType: "Outlet",
      entityName: outletName,
    })
  ) {
    return;
  }

  if (!validateNamePattern(outletName, "Outlet")) {
    return;
  }

  // Check for duplicates against core outlets
  if (BLOCK_OUTLETS.includes(outletName)) {
    raiseBlockError(
      `Outlet "${outletName}" is already registered as a core outlet.`
    );
    return;
  }

  // Check for duplicates against custom outlets
  if (customOutletRegistry.has(outletName)) {
    raiseBlockError(`Outlet "${outletName}" is already registered.`);
    return;
  }

  // Validate namespace requirements (shared consistency check with blocks and conditions)
  if (
    !validateSourceNamespace({
      name: outletName,
      entityType: "outlet",
    })
  ) {
    return;
  }

  customOutletRegistry.set(outletName, {
    name: outletName,
    displayName: options.displayName,
    description: options.description,
    category: options.category,
  });
}

/*
 * Test Utilities
 */

/**
 * Resets the outlet registry state for testing.
 *
 * USE ONLY FOR TESTING PURPOSES.
 *
 * @internal Called by `resetBlockRegistryForTesting`, not meant for direct use.
 */
export function _resetOutletRegistryState() {
  // allows tree-shaking in production builds
  if (!DEBUG) {
    return;
  }
  if (!isTesting()) {
    throw new Error("_resetOutletRegistryState can only be used in tests.");
  }
  customOutletRegistry.clear();
  outletRegistryFrozen = false;
}
