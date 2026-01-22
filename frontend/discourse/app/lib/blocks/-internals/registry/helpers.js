// @ts-check
import { DEBUG } from "@glimmer/env";
import { raiseBlockError } from "discourse/lib/blocks/-internals/error";
import {
  MAX_BLOCK_NAME_LENGTH,
  parseBlockName,
  VALID_NAMESPACED_BLOCK_PATTERN,
} from "discourse/lib/blocks/-internals/patterns";
import { isTesting } from "discourse/lib/environment";
import identifySource from "discourse/lib/source-identifier";

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
 * Override for source identifier in tests.
 * @type {string|null|undefined}
 */
let testSourceIdentifier;

/*
 * Public Functions
 */

/**
 * Asserts that a registry is not frozen before registration.
 *
 * @param {Object} options - Validation options.
 * @param {boolean} options.frozen - Whether the registry is frozen.
 * @param {string} options.apiMethod - The API method name for the error message.
 * @param {string} options.entityType - Type of entity (e.g., "Block", "Outlet", "Condition").
 * @param {string} options.entityName - Name of the entity being registered.
 * @returns {boolean} True if not frozen, false if frozen (error was raised).
 */
export function assertRegistryNotFrozen({
  frozen,
  apiMethod,
  entityType,
  entityName,
}) {
  if (frozen) {
    raiseBlockError(
      `${apiMethod} was called after the ${entityType.toLowerCase()} registry was frozen. ` +
        `Move your code to a pre-initializer that runs before "freeze-block-registry". ` +
        `${entityType}: "${entityName}"`
    );
    return false;
  }
  return true;
}

/**
 * Validates that a name follows the namespaced block/outlet name pattern.
 *
 * Checks both the pattern format and maximum length to prevent memory and
 * performance issues from extremely long names.
 *
 * @param {string} name - The name to validate.
 * @param {string} entityType - Type of entity for error messages (e.g., "Block", "Outlet").
 * @returns {boolean} True if valid, false if invalid (error was raised).
 */
export function validateNamePattern(name, entityType) {
  // Check length first to avoid regex issues with extremely long strings.
  if (name.length > MAX_BLOCK_NAME_LENGTH) {
    raiseBlockError(
      `${entityType} name exceeds maximum length of ${MAX_BLOCK_NAME_LENGTH} characters. ` +
        `Name length: ${name.length}.`
    );
    return false;
  }

  if (!VALID_NAMESPACED_BLOCK_PATTERN.test(name)) {
    const entityLower = entityType.toLowerCase();
    raiseBlockError(
      `${entityType} name "${name}" is invalid. ` +
        `Valid formats: "${entityLower}-name" (core), "plugin:${entityLower}-name" (plugin), ` +
        `"theme:namespace:${entityLower}-name" (theme).`
    );
    return false;
  }
  return true;
}

/**
 * Asserts that an entry is not already registered.
 *
 * @param {Map} registry - The registry to check.
 * @param {string} name - The name to check.
 * @param {string} entityType - Type of entity for error messages.
 * @returns {boolean} True if not duplicate, false if duplicate (error was raised).
 */
export function assertNotDuplicate(registry, name, entityType) {
  if (registry.has(name)) {
    raiseBlockError(`${entityType} "${name}" is already registered.`);
    return false;
  }
  return true;
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
export function validateSourceNamespace({
  name,
  entityType,
  enforceConsistency = true,
}) {
  const sourceId = getSourceIdentifier();
  if (!sourceId) {
    return true;
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

  // Enforce single namespace per source
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
 * Creates a test registration wrapper function for temporarily unfreezing a registry.
 *
 * USE ONLY FOR TESTING PURPOSES.
 *
 * @param {Object} options - Options object.
 * @param {() => boolean} options.getFrozen - Function to get frozen state.
 * @param {(value: boolean) => void} options.setFrozen - Function to set frozen state.
 * @param {() => boolean|null} options.getSavedState - Function to get saved test state.
 * @param {(value: boolean|null) => void} options.setSavedState - Function to set saved test state.
 * @param {string} options.name - Name for error message.
 * @returns {((callback: Function) => void)|undefined} The wrapper function.
 */
export function createTestRegistrationWrapper({
  getFrozen,
  setFrozen,
  getSavedState,
  setSavedState,
  name,
}) {
  // allows tree-shaking in production builds
  if (!DEBUG) {
    return; // this won't be called in production builds
  }
  return function (callback) {
    if (!isTesting()) {
      throw new Error(`Use \`${name}\` only in tests.`);
    }

    if (getSavedState() === null) {
      setSavedState(getFrozen());
    }

    setFrozen(false);
    try {
      callback();
    } finally {
      setFrozen(getSavedState());
    }
  };
}

/*
 * Internal Functions
 */

/**
 * Gets a unique identifier for the current source from the call stack.
 * Returns null for core code (no theme or plugin detected).
 *
 * @returns {string|null} Source identifier like "theme:Tactile" or "plugin:chat"
 */
function getSourceIdentifier() {
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
  return null;
}

/**
 * Internal implementation for setting the test source identifier.
 *
 * USE ONLY FOR TESTING PURPOSES.
 *
 * @param {string|null} sourceId - Source identifier to use, or null to clear.
 * @internal Called by `_setTestSourceIdentifier` in block-registry-testing.js.
 */
export function _setTestSourceIdentifierInternal(sourceId) {
  // allows tree-shaking in production builds
  if (!DEBUG) {
    return;
  }
  testSourceIdentifier = sourceId;
}

/**
 * Resets the source namespace map and test source identifier.
 *
 * USE ONLY FOR TESTING PURPOSES.
 *
 * @internal Called by `resetBlockRegistryForTesting`, not meant for direct use.
 */
export function _resetSourceNamespaceState() {
  // allows tree-shaking in production builds
  if (!DEBUG) {
    return;
  }
  if (!isTesting()) {
    throw new Error("_resetSourceNamespaceState can only be used in tests.");
  }
  sourceNamespaceMap.clear();
  testSourceIdentifier = undefined;
}
