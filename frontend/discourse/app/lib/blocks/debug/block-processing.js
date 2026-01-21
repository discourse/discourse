// @ts-check
/**
 * Block processing utilities and debug hooks.
 *
 * This module provides:
 * - Debug callback hooks for dev-tools integration (visual overlays, logging, outlet boundaries)
 * - Block processing utilities (optional missing blocks, container paths, ghost components)
 *
 * The debug hooks use TrackedMap for reactivity, enabling Ember's reactivity system
 * to trigger re-renders when callbacks are set/cleared.
 *
 * @module discourse/lib/blocks/debug/block-processing
 */

import { TrackedMap } from "@ember-compat/tracked-built-ins";
import { OPTIONAL_MISSING } from "discourse/lib/blocks/core/patterns";

/* Debug Hooks */

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

  /**
   * Returns whether visual overlay is enabled.
   *
   * @returns {boolean} True if visual overlay is enabled.
   */
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

/* Block Processing */

/**
 * Handles an optional missing block by logging and optionally creating a ghost.
 *
 * When a block reference ends with `?` but the block is not registered, this
 * function handles the logging and ghost component creation.
 *
 * @param {Object} options - Options for handling the missing block.
 * @param {string} options.blockName - The name of the missing block.
 * @param {Object} options.entry - The block entry.
 * @param {string} options.hierarchy - The hierarchy path for logging.
 * @param {boolean} options.isLoggingEnabled - Whether debug logging is enabled.
 * @param {boolean} options.showGhosts - Whether to show ghost components.
 * @param {string} options.key - Stable unique key for this block.
 * @returns {{Component: import("ember-curry-component").CurriedComponent, key: string}|null}
 *   Ghost component data with key if showGhosts is true, null otherwise.
 */
export function handleOptionalMissingBlock({
  blockName,
  entry,
  hierarchy,
  isLoggingEnabled,
  showGhosts,
  key,
}) {
  // Log if debug logging is enabled
  if (isLoggingEnabled) {
    debugHooks.getCallback(DEBUG_CALLBACK.OPTIONAL_MISSING_LOG)?.(
      blockName,
      hierarchy
    );
  }

  // Show ghost if visual overlay is enabled
  if (showGhosts) {
    const ghostData = debugHooks.getCallback(DEBUG_CALLBACK.BLOCK_DEBUG)(
      {
        name: blockName,
        Component: null,
        args: entry.args,
        conditions: entry.conditions,
        conditionsPassed: false,
        optionalMissing: true,
      },
      { outletName: hierarchy }
    );
    return ghostData?.Component ? { ...ghostData, key } : null;
  }

  return null;
}

/**
 * Checks if a resolved block is an optional missing block marker.
 *
 * @param {*} resolvedBlock - The result from resolveBlockSync.
 * @returns {boolean} True if the block is an optional missing marker.
 */
export function isOptionalMissing(resolvedBlock) {
  return resolvedBlock?.optionalMissing === OPTIONAL_MISSING;
}

/**
 * Builds a container path for nested containers.
 *
 * Maintains a count map to ensure unique indices for containers of the same type.
 * For example, if there are two "group" containers, they get paths like:
 * - `baseHierarchy/group[0]`
 * - `baseHierarchy/group[1]`
 *
 * @param {string} blockName - The block name.
 * @param {string} baseHierarchy - The base hierarchy path.
 * @param {Map<string, number>} containerCounts - Map tracking container counts.
 * @returns {string} The full container path.
 */
export function buildContainerPath(blockName, baseHierarchy, containerCounts) {
  const count = containerCounts.get(blockName) ?? 0;
  containerCounts.set(blockName, count + 1);
  return `${baseHierarchy}/${blockName}[${count}]`;
}

/**
 * Creates a ghost component for an invisible block.
 *
 * Ghost components are shown in debug mode to visualize blocks that failed
 * their conditions or have no visible children.
 *
 * @param {Object} options - Options for creating the ghost.
 * @param {string} options.blockName - The block name.
 * @param {Object} options.entry - The block entry.
 * @param {string} options.hierarchy - The hierarchy path for display.
 * @param {string|undefined} options.containerPath - Container path for child hierarchies.
 * @param {boolean} options.isContainer - Whether this block is a container.
 * @param {import("@ember/owner").default} options.owner - The application owner.
 * @param {Object} options.outletArgs - Outlet arguments.
 * @param {boolean} options.isLoggingEnabled - Whether debug logging is enabled.
 * @param {Function} options.resolveBlockFn - Function to resolve block references.
 * @param {string} options.key - Stable unique key for this block.
 * @returns {{Component: import("ember-curry-component").CurriedComponent, key: string}|null}
 *   Ghost component data with key if successful, null otherwise.
 */
export function createGhostBlock({
  blockName,
  entry,
  hierarchy,
  containerPath,
  isContainer,
  owner,
  outletArgs,
  isLoggingEnabled,
  resolveBlockFn,
  key,
}) {
  // For container blocks with children that failed due to no visible children,
  // recursively create ghost children so they appear nested in the debug overlay.
  let ghostChildren = null;
  if (
    isContainer &&
    entry.children?.length &&
    entry.__failureReason === "no-visible-children"
  ) {
    ghostChildren = debugHooks.getCallback(
      DEBUG_CALLBACK.GHOST_CHILDREN_CREATOR
    )?.(
      entry.children,
      owner,
      containerPath,
      outletArgs,
      isLoggingEnabled,
      resolveBlockFn
    );
  }

  const ghostData = debugHooks.getCallback(DEBUG_CALLBACK.BLOCK_DEBUG)(
    {
      name: blockName,
      Component: null,
      args: entry.args,
      containerArgs: entry.containerArgs,
      conditions: entry.conditions,
      conditionsPassed: false,
      failureReason: entry.__failureReason,
      children: ghostChildren,
    },
    { outletName: hierarchy }
  );

  return ghostData?.Component ? { ...ghostData, key } : null;
}
