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
 */
const sourceNamespaceMap = new Map<string, string | null>();

/** Override for source identifier in tests. */
let testSourceIdentifier: string | null | undefined;

/*
 * Public Functions
 */

/** Options for {@link assertRegistryNotFrozen}. */
interface AssertRegistryNotFrozenOptions {
  /** Whether the registry is frozen. */
  frozen: boolean;

  /** The API method name for the error message. */
  apiMethod: string;

  /** Type of entity (e.g., "Block", "Outlet", "Condition"). */
  entityType: string;

  /** Name of the entity being registered. */
  entityName: string;
}

/**
 * Asserts that a registry is not frozen before registration.
 *
 * @returns True if not frozen, false if frozen (error was raised).
 */
export function assertRegistryNotFrozen({
  frozen,
  apiMethod,
  entityType,
  entityName,
}: AssertRegistryNotFrozenOptions): boolean {
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
 * @param name - The name to validate.
 * @param entityType - Type of entity for error messages (e.g., "Block", "Outlet").
 * @returns True if valid, false if invalid (error was raised).
 */
export function validateNamePattern(name: string, entityType: string): boolean {
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
 * @param registry - The registry to check.
 * @param name - The name to check.
 * @param entityType - Type of entity for error messages.
 * @returns True if not duplicate, false if duplicate (error was raised).
 */
export function assertNotDuplicate<V>(
  registry: Map<string, V>,
  name: string,
  entityType: string
): boolean {
  if (registry.has(name)) {
    raiseBlockError(`${entityType} "${name}" is already registered.`);
    return false;
  }
  return true;
}

/** Options for {@link validateSourceNamespace}. */
interface ValidateSourceNamespaceOptions {
  /** The name being registered. */
  name: string;

  /** Type of entity for error messages. */
  entityType: "block" | "outlet" | "condition";

  /** Whether to enforce single namespace per source. Defaults to `true`. */
  enforceConsistency?: boolean;
}

/**
 * Validates that a block or outlet name follows namespace requirements for themes and plugins.
 *
 * This helper enforces the following rules:
 * - Themes must use `theme:namespace:name` format
 * - Plugins must use `namespace:name` format
 * - Optionally enforces that each source uses a consistent namespace across all registrations
 *
 * @returns True if validation passes, false if it failed (error was raised).
 */
export function validateSourceNamespace({
  name,
  entityType,
  enforceConsistency = true,
}: ValidateSourceNamespaceOptions): boolean {
  const sourceId = getSourceIdentifier();
  if (!sourceId) {
    return true;
  }

  const namespacePrefix = getNamespacePrefix(name);

  const ENTITY_PLURALS = {
    block: "blocks",
    outlet: "outlets",
    condition: "conditions",
  };
  const entityPlural = ENTITY_PLURALS[entityType] ?? "conditions";

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

  // Enforce single namespace per source (shared across blocks, outlets, and conditions)
  if (enforceConsistency) {
    const existingNamespace = sourceNamespaceMap.get(sourceId);
    if (
      existingNamespace !== undefined &&
      existingNamespace !== namespacePrefix
    ) {
      raiseBlockError(
        `${entityCapitalized} "${name}" uses namespace "${namespacePrefix ?? "(core)"}" but ` +
          `${sourceId} already used namespace "${existingNamespace ?? "(core)"}". ` +
          `Each theme/plugin must use a single consistent namespace for all blocks, outlets, and conditions.`
      );
      return false;
    }
    sourceNamespaceMap.set(sourceId, namespacePrefix);
  }

  return true;
}

/** Options for {@link createTestRegistrationWrapper}. */
interface TestRegistrationWrapperOptions {
  /** Function to get frozen state. */
  getFrozen: () => boolean;

  /** Function to set frozen state. */
  setFrozen: (value: boolean) => void;

  /** Function to get saved test state. */
  getSavedState: () => boolean | null;

  /** Function to set saved test state. */
  setSavedState: (value: boolean | null) => void;

  /** Name for error message. */
  name: string;
}

/**
 * Creates a test registration wrapper function for temporarily unfreezing a registry.
 *
 * USE ONLY FOR TESTING PURPOSES.
 *
 * @returns The wrapper function, or `undefined` outside of `DEBUG` builds.
 */
export function createTestRegistrationWrapper({
  getFrozen,
  setFrozen,
  getSavedState,
  setSavedState,
  name,
}: TestRegistrationWrapperOptions):
  | ((callback: () => void) => void)
  | undefined {
  // allows tree-shaking in production builds
  if (!DEBUG) {
    return; // this won't be called in production builds
  }
  return function (callback: () => void): void {
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
      // Invariant: the check above guarantees a saved (non-null) state by
      // the time this runs.
      setFrozen(getSavedState() as boolean);
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
 * @returns Source identifier like "theme:Tactile" or "plugin:chat"
 */
function getSourceIdentifier(): string | null {
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
 * @param blockName - The full block name.
 * @returns The namespace prefix, or null for core blocks.
 *
 * @example
 * ```
 * getNamespacePrefix("theme:tactile:banner") // => "theme:tactile"
 * getNamespacePrefix("chat:widget")          // => "chat"
 * getNamespacePrefix("group")                // => null (core)
 * ```
 */
function getNamespacePrefix(blockName: string): string | null {
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
 * @param sourceId - Source identifier to use, or null to clear.
 * @internal Called by `setTestSourceIdentifier` in block-testing.js.
 */
export function _setTestSourceIdentifierInternal(
  sourceId: string | null
): void {
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
export function _resetSourceNamespaceState(): void {
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
