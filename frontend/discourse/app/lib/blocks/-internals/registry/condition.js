// @ts-check
import { DEBUG } from "@glimmer/env";
import { isDecoratedCondition } from "discourse/blocks/conditions/decorator";
import { raiseBlockError } from "discourse/lib/blocks/-internals/error";
import { isTesting } from "discourse/lib/environment";
import {
  assertRegistryNotFrozen,
  createTestRegistrationWrapper,
} from "./helpers";

/*
 * Registry State
 */

/**
 * Registry of condition type classes registered by core, plugins, and themes.
 * Maps condition type names to their class constructors.
 *
 * Unlike blocks which store component classes, conditions are stored as classes
 * and instantiated by the Blocks service when first needed. This allows the
 * service to set the owner for dependency injection.
 *
 * @type {Map<string, typeof import("discourse/blocks/conditions").BlockCondition>}
 */
const conditionTypeRegistry = new Map();

/**
 * Whether the condition type registry is frozen (no new registrations allowed).
 */
let conditionTypeRegistryFrozen = false;

/**
 * Stores the initial frozen state for condition registry to allow correct reset after tests.
 * @type {boolean | null}
 */
let testConditionRegistryFrozenState = null;

/*
 * Public Functions
 */

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

/*
 * Internal Functions
 */

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
 * Registers a condition type class in the registry.
 * Must be called before the registry is frozen by the "freeze-block-registry" initializer.
 *
 * The condition class must be decorated with `@blockCondition`
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
 *     withPluginApi((api) => {
 *       api.registerBlockConditionType(MyCondition);
 *     });
 *   },
 * };
 * ```
 *
 * @internal
 */
export function _registerConditionType(ConditionClass) {
  if (
    !assertRegistryNotFrozen({
      frozen: conditionTypeRegistryFrozen,
      apiMethod: "api.registerBlockConditionType()",
      entityType: "Condition",
      entityName: ConditionClass?.type || ConditionClass?.name,
    })
  ) {
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

/*
 * Test Utilities
 */

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
export const withTestConditionRegistration = createTestRegistrationWrapper({
  getFrozen: () => conditionTypeRegistryFrozen,
  setFrozen: (value) => {
    conditionTypeRegistryFrozen = value;
  },
  getSavedState: () => testConditionRegistryFrozenState,
  setSavedState: (value) => {
    testConditionRegistryFrozenState = value;
  },
  name: "withTestConditionRegistration",
});

/**
 * Resets the condition registry state for testing.
 *
 * USE ONLY FOR TESTING PURPOSES.
 *
 * @internal Called by `resetBlockRegistryForTesting`, not meant for direct use.
 */
export function _resetConditionRegistryState() {
  // allows tree-shaking in production builds
  if (!DEBUG) {
    return;
  }
  if (!isTesting()) {
    throw new Error("_resetConditionRegistryState can only be used in tests.");
  }
  conditionTypeRegistry.clear();
  conditionTypeRegistryFrozen = false;
  testConditionRegistryFrozenState = null;
}
