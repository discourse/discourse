/**
 * Debug hooks for the block rendering system.
 *
 * This module provides callback registration for dev-tools integration.
 * Dev-tools can register callbacks to wrap blocks with debug overlays,
 * enable console logging, and show outlet boundaries.
 *
 * These hooks are intentionally separated from the core block-outlet module
 * to keep concerns separated and allow dev-tools to be loaded independently.
 *
 * @module discourse/lib/blocks/debug-hooks
 */

/**
 * Callback key constants for the debug hooks registry.
 * Use these instead of magic strings when calling getDebugCallback/setDebugCallback.
 */
export const DEBUG_CALLBACK = Object.freeze({
  BLOCK_DEBUG: "blockDebug",
  BLOCK_LOGGING: "blockLogging",
  OUTLET_BOUNDARY: "outletBoundary",
  OUTLET_INFO_COMPONENT: "outletInfoComponent",
  CONDITION_LOG: "conditionLog",
  COMBINATOR_LOG: "combinatorLog",
  CONDITION_RESULT: "conditionResult",
  PARAM_GROUP_LOG: "paramGroupLog",
  ROUTE_STATE_LOG: "routeStateLog",
  OPTIONAL_MISSING_LOG: "optionalMissingLog",
  START_GROUP: "startGroup",
  END_GROUP: "endGroup",
  LOGGER_INTERFACE: "loggerInterface",
  GHOST_CHILDREN_CREATOR: "ghostChildrenCreator",
});

/**
 * Callback registry for debug hooks.
 * All callbacks are registered here by dev-tools.
 *
 * @type {Object.<string, Function|null>}
 */
const callbacks = Object.seal(
  Object.fromEntries(Object.values(DEBUG_CALLBACK).map((key) => [key, null]))
);

/**
 * Gets a debug callback from the registry.
 *
 * @param {string} key - The callback key (use DEBUG_CALLBACK constants).
 * @returns {Function|null} The callback function, or null if not set.
 */
export function getDebugCallback(key) {
  return callbacks[key];
}

/**
 * Sets a debug callback in the registry.
 * Used by dev-tools to register debug hooks.
 *
 * @param {string} key - The callback key (use DEBUG_CALLBACK constants).
 * @param {Function|null} value - The callback function, or null to clear.
 * @throws {Error} If the key is not a valid callback key.
 */
export function setDebugCallback(key, value) {
  if (!(key in callbacks)) {
    const validKeys = Object.values(DEBUG_CALLBACK).join(", ");
    throw new Error(
      `[Blocks] Unknown debug callback key: "${key}". Valid keys are: ${validKeys}.`
    );
  }
  callbacks[key] = value;
}

/**
 * Returns whether console logging is enabled.
 * Convenience wrapper that invokes the blockLogging callback.
 *
 * @returns {boolean} True if logging is enabled.
 */
export function isBlockLoggingEnabled() {
  return callbacks[DEBUG_CALLBACK.BLOCK_LOGGING]?.() ?? false;
}

/**
 * Returns whether outlet boundaries should be shown.
 * Convenience wrapper that invokes the outletBoundary callback.
 *
 * @returns {boolean} True if boundaries should be shown.
 */
export function isOutletBoundaryEnabled() {
  return callbacks[DEBUG_CALLBACK.OUTLET_BOUNDARY]?.() ?? false;
}

/**
 * Returns the logger interface for conditions to use.
 * Convenience wrapper that invokes the loggerInterface callback.
 *
 * The interface has methods: logCondition, updateCombinatorResult,
 * logParamGroup, logRouteState.
 *
 * @returns {Object|null} The logger interface, or null if not available.
 */
export function getLoggerInterface() {
  return callbacks[DEBUG_CALLBACK.LOGGER_INTERFACE]?.() ?? null;
}
