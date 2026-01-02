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
