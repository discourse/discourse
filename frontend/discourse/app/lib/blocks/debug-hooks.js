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
 * Debug callback for block rendering.
 * Set by dev-tools to wrap blocks with debug overlays.
 *
 * @type {Function|null}
 */
let blockDebugCallback = null;

/**
 * Callback for checking if console logging is enabled.
 * Set by dev-tools, returns true when block debug logging is active.
 *
 * @type {Function|null}
 */
let blockLoggingCallback = null;

/**
 * Callback for checking if outlet boundaries should be shown.
 * Set by dev-tools, returns true when outlet boundary overlay is active.
 *
 * @type {Function|null}
 */
let blockOutletBoundaryCallback = null;

/**
 * Component to render for outlet boundary debug overlay.
 * Set by dev-tools to provide the OutletInfo component.
 *
 * @type {typeof import("@glimmer/component").default|null}
 */
let blockOutletInfoComponent = null;

// ============================================================================
// Logging Callbacks
// ============================================================================
// These callbacks enable moving the debug logger to the dev-tools bundle.
// When dev tools are not loaded, these remain null and logging is a no-op.

/**
 * Callback for logging a condition evaluation.
 * Receives: { type, args, result, depth, resolvedValue }
 *
 * @type {Function|null}
 */
let conditionLogCallback = null;

/**
 * Callback for updating a combinator's result after children evaluated.
 * Receives: { conditionSpec, result }
 *
 * @type {Function|null}
 */
let combinatorLogCallback = null;

/**
 * Callback for updating a single condition's result after evaluation.
 * Receives: { conditionSpec, result }
 *
 * @type {Function|null}
 */
let conditionResultCallback = null;

/**
 * Callback for logging param group matches.
 * Receives: { label, matches, result, depth }
 *
 * @type {Function|null}
 */
let paramGroupLogCallback = null;

/**
 * Callback for logging current route state.
 * Receives: { currentPath, expectedUrls, excludeUrls, actualParams, actualQueryParams, depth, result }
 *
 * @type {Function|null}
 */
let routeStateLogCallback = null;

/**
 * Callback for logging optional missing blocks.
 * Receives: (blockName, hierarchy)
 *
 * @type {Function|null}
 */
let optionalMissingLogCallback = null;

/**
 * Callback for starting a logging group for a block.
 * Receives: (blockName, hierarchy)
 *
 * @type {Function|null}
 */
let startGroupCallback = null;

/**
 * Callback for ending a logging group and flushing to console.
 * Receives: (finalResult)
 *
 * @type {Function|null}
 */
let endGroupCallback = null;

/**
 * Callback that returns the logger interface for conditions.
 * Returns an object with methods: logCondition, updateCombinatorResult,
 * logParamGroup, logRouteState.
 *
 * @type {Function|null}
 */
let loggerInterfaceCallback = null;

/**
 * Returns the current debug callback for block rendering.
 *
 * @returns {Function|null} The callback or null if not set
 */
export function getBlockDebugCallback() {
  return blockDebugCallback;
}

/**
 * Returns whether console logging is enabled.
 *
 * @returns {boolean} True if logging is enabled
 */
export function isBlockLoggingEnabled() {
  return blockLoggingCallback?.() ?? false;
}

/**
 * Returns whether outlet boundaries should be shown.
 *
 * @returns {boolean} True if boundaries should be shown
 */
export function isOutletBoundaryEnabled() {
  return blockOutletBoundaryCallback?.() ?? false;
}

/**
 * Returns the component to render for outlet boundary debug info.
 *
 * @returns {typeof import("@glimmer/component").default|null} The component or null
 */
export function getOutletInfoComponent() {
  return blockOutletInfoComponent;
}

// ============================================================================
// Logging Callback Getters
// ============================================================================

/**
 * Returns the callback for logging condition evaluations, or null if not set.
 *
 * @returns {Function|null}
 */
export function getConditionLogCallback() {
  return conditionLogCallback;
}

/**
 * Returns the callback for updating combinator results, or null if not set.
 *
 * @returns {Function|null}
 */
export function getCombinatorLogCallback() {
  return combinatorLogCallback;
}

/**
 * Returns the callback for updating single condition results, or null if not set.
 *
 * @returns {Function|null}
 */
export function getConditionResultCallback() {
  return conditionResultCallback;
}

/**
 * Returns the callback for logging param group matches, or null if not set.
 *
 * @returns {Function|null}
 */
export function getParamGroupLogCallback() {
  return paramGroupLogCallback;
}

/**
 * Returns the callback for logging route state, or null if not set.
 *
 * @returns {Function|null}
 */
export function getRouteStateLogCallback() {
  return routeStateLogCallback;
}

/**
 * Returns the callback for logging optional missing blocks, or null if not set.
 *
 * @returns {Function|null}
 */
export function getOptionalMissingLogCallback() {
  return optionalMissingLogCallback;
}

/**
 * Returns the callback for starting a logging group, or null if not set.
 *
 * @returns {Function|null}
 */
export function getStartGroupCallback() {
  return startGroupCallback;
}

/**
 * Returns the callback for ending a logging group, or null if not set.
 *
 * @returns {Function|null}
 */
export function getEndGroupCallback() {
  return endGroupCallback;
}

/**
 * Returns the logger interface for conditions to use.
 * The interface has methods: logCondition, updateCombinatorResult,
 * logParamGroup, logRouteState.
 *
 * @returns {Object|null} The logger interface, or null if not available
 */
export function getLoggerInterface() {
  return loggerInterfaceCallback?.() ?? null;
}

/**
 * Sets a callback for debug overlay injection.
 * Called by dev-tools to wrap rendered blocks with debug info.
 *
 * @param {Function} callback - Callback receiving (blockData, context)
 */
export function _setBlockDebugCallback(callback) {
  blockDebugCallback = callback;
}

/**
 * Sets a callback for checking if console logging is enabled.
 * Called by dev-tools to provide state access without window globals.
 *
 * @param {Function} callback - Callback returning boolean
 */
export function _setBlockLoggingCallback(callback) {
  blockLoggingCallback = callback;
}

/**
 * Sets a callback for checking if outlet boundaries should be shown.
 * Called by dev-tools to provide state access without window globals.
 *
 * @param {Function} callback - Callback returning boolean
 */
export function _setBlockOutletBoundaryCallback(callback) {
  blockOutletBoundaryCallback = callback;
}

/**
 * Sets the component to render for outlet boundary debug overlay.
 * Called by dev-tools to provide the OutletInfo component.
 *
 * @param {typeof import("@glimmer/component").default} component - The OutletInfo component
 */
export function _setBlockOutletInfoComponent(component) {
  blockOutletInfoComponent = component;
}

// ============================================================================
// Logging Callback Setters
// ============================================================================

/**
 * Sets the callback for logging condition evaluations.
 * Called by dev-tools to register the logger.
 *
 * @param {Function} callback - Callback receiving { type, args, result, depth, resolvedValue }
 */
export function _setConditionLogCallback(callback) {
  conditionLogCallback = callback;
}

/**
 * Sets the callback for updating combinator results.
 * Called by dev-tools to register the logger.
 *
 * @param {Function} callback - Callback receiving { conditionSpec, result }
 */
export function _setCombinatorLogCallback(callback) {
  combinatorLogCallback = callback;
}

/**
 * Sets the callback for updating single condition results.
 * Called by dev-tools to register the logger.
 *
 * @param {Function} callback - Callback receiving { conditionSpec, result }
 */
export function _setConditionResultCallback(callback) {
  conditionResultCallback = callback;
}

/**
 * Sets the callback for logging param group matches.
 * Called by dev-tools to register the logger.
 *
 * @param {Function} callback - Callback receiving { label, matches, result, depth }
 */
export function _setParamGroupLogCallback(callback) {
  paramGroupLogCallback = callback;
}

/**
 * Sets the callback for logging route state.
 * Called by dev-tools to register the logger.
 *
 * @param {Function} callback - Callback receiving route state object
 */
export function _setRouteStateLogCallback(callback) {
  routeStateLogCallback = callback;
}

/**
 * Sets the callback for logging optional missing blocks.
 * Called by dev-tools to register the logger.
 *
 * @param {Function} callback - Callback receiving (blockName, hierarchy)
 */
export function _setOptionalMissingLogCallback(callback) {
  optionalMissingLogCallback = callback;
}

/**
 * Sets the callback for starting a logging group.
 * Called by dev-tools to register the logger.
 *
 * @param {Function} callback - Callback receiving (blockName, hierarchy)
 */
export function _setStartGroupCallback(callback) {
  startGroupCallback = callback;
}

/**
 * Sets the callback for ending a logging group.
 * Called by dev-tools to register the logger.
 *
 * @param {Function} callback - Callback receiving (finalResult)
 */
export function _setEndGroupCallback(callback) {
  endGroupCallback = callback;
}

/**
 * Sets the callback for getting the logger interface.
 * Called by dev-tools to provide the logger interface for conditions.
 *
 * @param {Function} callback - Callback returning the logger interface object
 */
export function _setLoggerInterfaceCallback(callback) {
  loggerInterfaceCallback = callback;
}
