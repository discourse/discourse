// @ts-check
import { _resetBlockRegistryState } from "discourse/lib/blocks/registry/block";
import { _resetConditionRegistryState } from "discourse/lib/blocks/registry/condition";
import {
  _resetSourceNamespaceState,
  _setTestSourceIdentifierInternal,
} from "discourse/lib/blocks/registry/helpers";
import { _resetOutletRegistryState } from "discourse/lib/blocks/registry/outlet";
import { isTesting } from "discourse/lib/environment";

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
export function _setTestSourceIdentifier(sourceId) {
  if (!isTesting()) {
    throw new Error("_setTestSourceIdentifier can only be used in tests.");
  }
  _setTestSourceIdentifierInternal(sourceId);
}
