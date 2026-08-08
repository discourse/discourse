import { DEBUG } from "@glimmer/env";
import type { BlockNamespaceType } from "discourse/blocks/types";
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
 * The fully-resolved display metadata for a registered outlet (core or
 * custom), as returned by {@link getOutletMetadata}. Optional fields are
 * resolved to defaults so callers don't have to.
 */
export interface OutletMetadataEntry {
  /** The full outlet identifier (e.g. `"chat:thread-actions"`). */
  name: string;

  /** Human-readable label for display purposes. */
  displayName: string | null;

  /** One-line summary of where the outlet renders. */
  description: string | null;

  /** Optional sub-grouping label (free-form, e.g. `"Layout"`). */
  category: string | null;

  /** True for the outlets baked into core. */
  isCore: boolean;

  /** Derived from the outlet name's namespace prefix. */
  namespaceType: BlockNamespaceType;
}

/** Metadata recorded for a custom block outlet. */
interface CustomOutletMetadata {
  /** The outlet name. */
  name: string;

  /** Human-readable label for display purposes. */
  displayName?: string;

  /** Human-readable description. */
  description?: string;

  /** Optional sub-grouping label. */
  category?: string;
}

/*
 * Registry State
 */

/**
 * Registry of custom block outlets registered by plugins and themes.
 * Maps outlet names to their metadata.
 */
const customOutletRegistry = new Map<string, CustomOutletMetadata>();

/** Whether the outlet registry is frozen (no new registrations allowed). */
let outletRegistryFrozen = false;

/*
 * Public Functions
 */

/** Returns whether the outlet registry is frozen. */
export function isOutletRegistryFrozen(): boolean {
  return outletRegistryFrozen;
}

/**
 * Returns all valid outlet names (both core and custom).
 *
 * @returns Array of all outlet names.
 */
export function getAllOutlets(): string[] {
  return [...BLOCK_OUTLETS, ...customOutletRegistry.keys()];
}

/**
 * Checks if an outlet name is valid (registered as core or custom).
 *
 * @param name - The outlet name to check.
 * @returns True if the outlet is registered.
 */
export function isValidOutlet(name: string): boolean {
  return BLOCK_OUTLETS.includes(name) || customOutletRegistry.has(name);
}

/**
 * Gets metadata for a custom outlet.
 *
 * @param name - The outlet name.
 * @returns Outlet metadata or undefined.
 */
export function getCustomOutlet(
  name: string
): CustomOutletMetadata | undefined {
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
 * @param name - The full outlet name.
 * @returns The metadata, or `null` for unregistered names.
 */
export function getOutletMetadata(name: string): OutletMetadataEntry | null {
  const coreMeta = CORE_OUTLET_METADATA[name];
  if (coreMeta) {
    return {
      name,
      displayName: coreMeta.displayName ?? name,
      description: coreMeta.description ?? null,
      category: coreMeta.category ?? null,
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
 * Used by the blocks service to list outlets with their metadata.
 *
 * @returns The metadata for every registered outlet.
 */
export function getAllOutletsWithMetadata(): OutletMetadataEntry[] {
  return getAllOutlets()
    .map((name) => getOutletMetadata(name))
    .filter((m): m is OutletMetadataEntry => m != null);
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
export function _freezeOutletRegistry(): void {
  outletRegistryFrozen = true;
}

/** Options for {@link _registerOutlet}. */
interface RegisterOutletOptions {
  /** Human-readable label for display purposes. Defaults to the outlet name. */
  displayName?: string;

  /** One-line summary of where the outlet renders. */
  description?: string;

  /** Optional free-form grouping label (e.g. `"Layout"`). */
  category?: string;
}

/**
 * Registers a custom block outlet.
 *
 * Custom outlets follow the same naming conventions as blocks:
 * - Core outlets: `outlet-name` (kebab-case)
 * - Plugin outlets: `namespace:outlet-name`
 * - Theme outlets: `theme:namespace:outlet-name`
 *
 * @param outletName - The outlet name (must follow naming conventions).
 * @param options - Outlet options.
 *
 * @internal
 */
export function _registerOutlet(
  outletName: string,
  options: RegisterOutletOptions = {}
): void {
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
export function _resetOutletRegistryState(): void {
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
