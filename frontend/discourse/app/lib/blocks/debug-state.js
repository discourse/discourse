import { tracked } from "@glimmer/tracking";

/**
 * Block debug state management.
 *
 * This module provides a centralized state object for block debugging features.
 * It can be imported directly by both the main bundle (Blocks service) and the
 * dev-tools bundle without relying on window globals.
 *
 * @module discourse/lib/blocks/debug-state
 */
class BlockDebugState {
  /**
   * Enable console logging of condition evaluations.
   *
   * @type {boolean}
   */
  @tracked enabled = false;

  /**
   * Enable visual overlay showing block boundaries and info.
   *
   * @type {boolean}
   */
  @tracked visualOverlay = false;
}

const blockDebugState = new BlockDebugState();
Object.preventExtensions(blockDebugState);

export default blockDebugState;

/**
 * Enable block debug logging.
 *
 * @param {boolean} [enabled=true] - Whether to enable debug logging
 *
 * @example
 * ```javascript
 * import { enableBlockDebug } from "discourse/blocks";
 * enableBlockDebug(); // Enable console logging
 * ```
 */
export function enableBlockDebug(enabled = true) {
  blockDebugState.enabled = enabled;
}

/**
 * Disable block debug logging.
 *
 * @example
 * ```javascript
 * import { disableBlockDebug } from "discourse/blocks";
 * disableBlockDebug();
 * ```
 */
export function disableBlockDebug() {
  blockDebugState.enabled = false;
}

/**
 * Check if block debug logging is enabled.
 *
 * @returns {boolean}
 *
 * @example
 * ```javascript
 * import { isBlockDebugEnabled } from "discourse/blocks";
 * if (isBlockDebugEnabled()) {
 *   // Debug mode is active
 * }
 * ```
 */
export function isBlockDebugEnabled() {
  return blockDebugState.enabled;
}

/**
 * Enable visual overlay for blocks.
 *
 * @param {boolean} [enabled=true] - Whether to enable visual overlay
 *
 * @example
 * ```javascript
 * import { enableBlockVisualOverlay } from "discourse/blocks";
 * enableBlockVisualOverlay(); // Show block boundaries
 * ```
 */
export function enableBlockVisualOverlay(enabled = true) {
  blockDebugState.visualOverlay = enabled;
}

/**
 * Check if visual overlay is enabled.
 *
 * @returns {boolean}
 */
export function isBlockVisualOverlayEnabled() {
  return blockDebugState.visualOverlay;
}
