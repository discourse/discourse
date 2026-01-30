// @ts-check
import { DEBUG } from "@glimmer/env";
import { raiseBlockError } from "discourse/lib/blocks/-internals/error";
import { isTesting } from "discourse/lib/environment";
import { BLOCK_OUTLETS } from "discourse/lib/registry/block-outlets";
import {
  assertRegistryNotFrozen,
  validateNamePattern,
  validateSourceNamespace,
} from "./helpers";

/*
 * Registry State
 */

/**
 * Registry of custom block outlets registered by plugins and themes.
 * Maps outlet names to their metadata.
 *
 * @type {Map<string, { name: string, description?: string }>}
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
 * @returns {{ name: string, description?: string } | undefined} Outlet metadata or undefined.
 */
export function getCustomOutlet(name) {
  return customOutletRegistry.get(name);
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
 * @param {string} [options.description] - Human-readable description.
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
    description: options.description,
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
