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
 * The DebugHooks class uses TrackedMap for the callback registry, enabling
 * Ember's reactivity system to trigger re-renders when callbacks are set/cleared.
 *
 * @module discourse/lib/blocks/debug-hooks
 */

import { TrackedMap } from "@ember-compat/tracked-built-ins";

/**
 * Callback key constants for the debug hooks registry.
 * Use these instead of magic strings when calling debugHooks.getCallback/setCallback.
 */
export const DEBUG_CALLBACK = Object.freeze({
  BLOCK_DEBUG: "blockDebug",
  BLOCK_LOGGING: "blockLogging",
  OUTLET_BOUNDARY: "outletBoundary",
  VISUAL_OVERLAY: "visualOverlay",
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
 * Singleton class that manages debug callback hooks for the block rendering system.
 * Uses TrackedMap for reactivity, so components accessing these values will re-render
 * when callbacks are set or cleared.
 */
class DebugHooks {
  /**
   * Tracked callback registry for debug hooks.
   * Using TrackedMap enables reactivity when callbacks are set/cleared.
   *
   * @type {TrackedMap<string, Function|null>}
   */
  #callbacks = new TrackedMap(
    Object.values(DEBUG_CALLBACK).map((key) => [key, null])
  );

  /**
   * Gets a debug callback from the registry.
   *
   * @param {string} key - The callback key (use DEBUG_CALLBACK constants).
   * @returns {Function|null} The callback function, or null if not set.
   */
  getCallback(key) {
    return this.#callbacks.get(key);
  }

  /**
   * Sets a debug callback in the registry.
   * Used by dev-tools to register debug hooks.
   *
   * @param {string} key - The callback key (use DEBUG_CALLBACK constants).
   * @param {Function|null} value - The callback function, or null to clear.
   * @throws {Error} If the key is not a valid callback key.
   */
  setCallback(key, value) {
    if (!this.#callbacks.has(key)) {
      const validKeys = Object.values(DEBUG_CALLBACK).join(", ");
      throw new Error(
        `[Blocks] Unknown debug callback key: "${key}". Valid keys are: ${validKeys}.`
      );
    }
    this.#callbacks.set(key, value);
  }

  /**
   * Returns whether console logging is enabled.
   * Convenience getter that invokes the blockLogging callback.
   *
   * @returns {boolean} True if logging is enabled.
   */
  get isBlockLoggingEnabled() {
    return this.#callbacks.get(DEBUG_CALLBACK.BLOCK_LOGGING)?.() ?? false;
  }

  /**
   * Returns whether outlet boundaries should be shown.
   * Convenience getter that invokes the outletBoundary callback.
   *
   * @returns {boolean} True if boundaries should be shown.
   */
  get isOutletBoundaryEnabled() {
    return this.#callbacks.get(DEBUG_CALLBACK.OUTLET_BOUNDARY)?.() ?? false;
  }

  get isVisualOverlayEnabled() {
    return this.#callbacks.get(DEBUG_CALLBACK.VISUAL_OVERLAY)?.() ?? false;
  }

  /**
   * Returns the logger interface for conditions to use.
   * Convenience getter that invokes the loggerInterface callback.
   *
   * The interface has methods: logCondition, updateCombinatorResult,
   * logParamGroup, logRouteState.
   *
   * @returns {Object|null} The logger interface, or null if not available.
   */
  get loggerInterface() {
    return this.#callbacks.get(DEBUG_CALLBACK.LOGGER_INTERFACE)?.() ?? null;
  }
}

/**
 * Singleton instance of DebugHooks.
 * Import this to access debug callbacks with tracked reactivity.
 */
export const debugHooks = new DebugHooks();
