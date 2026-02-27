// @ts-check
/**
 * Testing utilities for the Discourse Block system.
 *
 * This module provides helpers for plugin and theme developers to test
 * their custom blocks and conditions. These utilities temporarily unfreeze
 * registries to allow registration during tests.
 *
 * @module discourse/tests/helpers/block-testing
 *
 * @example
 * import {
 *   withTestBlockRegistration,
 *   registerBlock,
 *   withTestConditionRegistration,
 *   registerConditionType,
 *   resetBlockRegistryForTesting,
 *   hasBlock,
 *   isValidOutlet,
 * } from "discourse/tests/helpers/block-testing";
 *
 * // Register a block for testing
 * withTestBlockRegistration(() => registerBlock(MyCustomBlock));
 *
 * // Register a condition for testing
 * withTestConditionRegistration(() => registerConditionType(MyCondition));
 *
 * // Assert block was registered
 * assert.true(hasBlock("my-block"));
 */

import {
  DEBUG_CALLBACK,
  debugHooks,
} from "discourse/lib/blocks/-internals/debug-hooks";
import { FAILURE_TYPE } from "discourse/lib/blocks/-internals/patterns";
import {
  _freezeBlockRegistry,
  _registerBlock,
  _registerBlockFactory,
  _resetBlockRegistryState,
  getBlockEntry,
  hasBlock,
  isBlockFactory,
  isBlockRegistryFrozen,
  isBlockResolved,
  resolveBlock,
  tryResolveBlock,
  withTestBlockRegistration,
} from "discourse/lib/blocks/-internals/registry/block";
import {
  _freezeConditionTypeRegistry,
  _registerConditionType,
  _resetConditionRegistryState,
  hasConditionType,
  isConditionTypeRegistryFrozen,
  withTestConditionRegistration,
} from "discourse/lib/blocks/-internals/registry/condition";
import {
  _resetSourceNamespaceState,
  _setTestSourceIdentifierInternal,
} from "discourse/lib/blocks/-internals/registry/helpers";
import {
  _freezeOutletRegistry,
  _registerOutlet,
  _resetOutletRegistryState,
  getAllOutlets,
  getCustomOutlet,
  isOutletRegistryFrozen,
  isValidOutlet,
} from "discourse/lib/blocks/-internals/registry/outlet";
import { validateConditions } from "discourse/lib/blocks/-internals/validation/conditions";
import { isTesting } from "discourse/lib/environment";

/*
 * Block Registration
 **/

/**
 * Freezes the block registry, preventing further registrations.
 * Useful for testing frozen state behavior.
 */
export { _freezeBlockRegistry as freezeBlockRegistry };

/**
 * Registers a block class with the block registry.
 * Use inside withTestBlockRegistration callback.
 *
 * @example
 * withTestBlockRegistration(() => registerBlock(MyBlock));
 */
export { _registerBlock as registerBlock };

/**
 * Registers a factory function for lazy loading a block.
 * Use inside withTestBlockRegistration callback.
 *
 * @example
 * withTestBlockRegistration(() => {
 *   registerBlockFactory("lazy-block", async () => LazyBlock);
 * });
 */
export { _registerBlockFactory as registerBlockFactory };

/**
 * Temporarily unfreezes the block registry to allow registration during tests.
 * Takes a callback that performs registration, then re-freezes the registry.
 *
 * @example
 * withTestBlockRegistration(() => registerBlock(MyBlock));
 */
export { withTestBlockRegistration };

/*
 * Block Registry Queries
 **/

/**
 * Returns the registry entry for a block (class or factory).
 */
export { getBlockEntry };

/**
 * Checks if a block is registered (by name or class reference).
 *
 * @example
 * assert.true(hasBlock("my-block"));
 */
export { hasBlock };

/**
 * Checks if a registry entry is a factory function (not a resolved class).
 */
export { isBlockFactory };

/**
 * Returns whether the block registry is frozen.
 */
export { isBlockRegistryFrozen };

/**
 * Checks if a block is registered and fully resolved (not a pending factory).
 */
export { isBlockResolved };

/**
 * Resolves a block reference (string name or class) to a BlockClass.
 * Async - use for testing factory resolution.
 */
export { resolveBlock };

/**
 * Attempts to resolve a block reference synchronously.
 * Returns the BlockClass if found and resolved, null if pending or not found.
 */
export { tryResolveBlock };

/*
 * Outlet Registration
 **/

/**
 * Freezes the outlet registry, preventing further registrations.
 * Useful for testing frozen state behavior.
 */
export { _freezeOutletRegistry as freezeOutletRegistry };

/**
 * Registers a custom outlet for testing.
 * Use inside withTestBlockRegistration callback.
 *
 * @example
 * withTestBlockRegistration(() => {
 *   registerOutlet("test-outlet", { description: "For testing" });
 * });
 */
export { _registerOutlet as registerOutlet };

/*
 * Outlet Registry Queries
 **/

/**
 * Returns all registered outlets (core + custom).
 */
export { getAllOutlets };

/**
 * Returns custom outlet data for a registered custom outlet.
 */
export { getCustomOutlet };

/**
 * Returns whether the outlet registry is frozen.
 */
export { isOutletRegistryFrozen };

/**
 * Checks if an outlet name is valid (registered as core or custom outlet).
 *
 * @example
 * assert.true(isValidOutlet("sidebar-blocks"));
 */
export { isValidOutlet };

/*
 * Condition Registration
 **/

/**
 * Freezes the condition type registry, preventing further registrations.
 * Useful for testing frozen state behavior.
 */
export { _freezeConditionTypeRegistry as freezeConditionTypeRegistry };

/**
 * Registers a condition class with the condition registry.
 * Use inside withTestConditionRegistration callback.
 *
 * @example
 * withTestConditionRegistration(() => registerConditionType(MyCondition));
 */
export { _registerConditionType as registerConditionType };

/**
 * Temporarily unfreezes the condition registry to allow registration during tests.
 * Takes a callback that performs registration, then re-freezes the registry.
 *
 * @example
 * withTestConditionRegistration(() => registerConditionType(MyCondition));
 */
export { withTestConditionRegistration };

/*
 * Condition Registry Queries
 **/

/**
 * Checks if a condition type is registered.
 *
 * @example
 * assert.true(hasConditionType("user"));
 */
export { hasConditionType };

/**
 * Returns whether the condition type registry is frozen.
 */
export { isConditionTypeRegistryFrozen };

/**
 * Validates a condition specification against the registered condition types.
 * Throws detailed errors if the specification is invalid.
 */
export { validateConditions };

/**
 * Constants for block failure types used in debug mode.
 * Used to identify why a block didn't render (conditions failed, optional missing, etc.).
 */
export { FAILURE_TYPE };

/*
 * Debug Utilities
 **/

/**
 * Debug callback type constants.
 * Used with debugHooks.setCallback() for testing debug behavior.
 */
export { DEBUG_CALLBACK };

/**
 * Debug hook interface for testing debug mode behavior.
 * Provides reactive getters and callback management.
 */
export { debugHooks };

/**
 * Sets up debug callbacks to capture ghost blocks and render them with standard markup.
 * Returns an array that will be populated with ghost data as blocks are processed.
 *
 * The rendered ghost blocks have:
 * - class="ghost-block"
 * - data-name={blockName}
 * - data-type={failureType}
 * - data-reason={failureReason}
 *
 * @param {Object} [options] - Configuration options.
 * @param {boolean} [options.enabled=true] - Whether ghost blocks are enabled.
 *   Set to false to test that ghosts aren't rendered when debug mode is disabled.
 * @returns {Array<{name: string, failureType: string, failureReason: string|undefined}>}
 *
 * @example
 * const capturedGhosts = setupGhostCapture();
 * // ... register blocks and render ...
 * assert.dom('.ghost-block[data-name="my-block"]').exists();
 * assert.strictEqual(capturedGhosts[0].name, "my-block");
 */
export function setupGhostCapture({ enabled = true } = {}) {
  const capturedGhosts = [];

  debugHooks.setCallback(DEBUG_CALLBACK.GHOST_BLOCKS, () => enabled);
  debugHooks.setCallback(DEBUG_CALLBACK.BLOCK_DEBUG, (blockData) => {
    if (blockData.conditionsPassed === false) {
      capturedGhosts.push({
        name: blockData.name,
        failureType: blockData.failureType,
        failureReason: blockData.failureReason,
      });
      return {
        Component: <template>
          <div
            class="ghost-block"
            data-name={{blockData.name}}
            data-type={{blockData.failureType}}
            data-reason={{blockData.failureReason}}
          >Ghost: {{blockData.name}}</div>
        </template>,
        isGhost: true,
        asGhost: () => null,
      };
    }
    return { Component: blockData.Component };
  });

  return capturedGhosts;
}

/**
 * Resets all debug callbacks to null.
 * Use in afterEach hooks to clean up debug state between tests.
 *
 * @example
 * hooks.afterEach(function () {
 *   resetDebugCallbacks();
 * });
 */
export function resetDebugCallbacks() {
  for (const key of Object.values(DEBUG_CALLBACK)) {
    debugHooks.setCallback(key, null);
  }
}

/*
 * Reset Utilities
 **/

/**
 * Resets all registries (blocks, outlets, conditions) for testing.
 *
 * USE ONLY FOR TESTING PURPOSES.
 *
 * Clears all registered entities and restores the original frozen state.
 */
export function resetBlockRegistryForTesting() {
  if (!isTesting()) {
    throw new Error("resetBlockRegistryForTesting can only be used in tests.");
  }

  _resetBlockRegistryState();
  _resetOutletRegistryState();
  _resetConditionRegistryState();
  _resetSourceNamespaceState();
}

/**
 * Sets a test override for the source identifier.
 *
 * USE ONLY FOR TESTING PURPOSES.
 *
 * @param {string|null} sourceId - Source identifier to use, or null to clear.
 */
export function setTestSourceIdentifier(sourceId) {
  if (!isTesting()) {
    throw new Error("setTestSourceIdentifier can only be used in tests.");
  }
  _setTestSourceIdentifierInternal(sourceId);
}
