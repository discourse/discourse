import { headerOffset } from "discourse/lib/offset-calculator";

/**
 * Floor for a box that reports no usable minimum.
 *
 * Narrower than it looks: `getComputedStyle` resolves an undeclared `min-height`
 * to `0px` on a block box, and to `auto` only on a flex or grid item. So this
 * catches those items and a box that is not in the document, while a plain box
 * declaring nothing clamps at zero.
 */
export const DEFAULT_MIN_HEIGHT = 250;

/**
 * The box's current height.
 *
 * @param {HTMLElement|null|undefined} element - The box being resized.
 * @returns {number|null} The height in pixels, or `null` when there is nothing
 *   to measure. Null rather than zero because a resize reads it as "not measured
 *   yet" and declines to start, where zero would claim the box has no extent and
 *   drag on from there.
 */
export function measuredHeight(element) {
  return element?.offsetHeight ?? null;
}

/**
 * The smallest height the box may be dragged to, read from the stylesheet so the
 * two cannot drift apart.
 *
 * @param {HTMLElement|null|undefined} element - The box being resized.
 * @param {number} [fallback] - Used when the box declares no minimum.
 * @returns {number} The minimum height, in pixels.
 */
export function measuredMinHeight(element, fallback = DEFAULT_MIN_HEIGHT) {
  if (!element) {
    return fallback;
  }

  const declared = getComputedStyle(element).minHeight;
  return declared === "auto" ? fallback : parseInt(declared, 10);
}

/**
 * What is left of the viewport once the header has its space, which is as tall as
 * a box can grow without covering the header.
 *
 * @returns {number} The available height, in pixels.
 */
export function viewportCap() {
  return window.innerHeight - headerOffset();
}

/**
 * The largest height the box may be dragged to.
 *
 * @param {HTMLElement|null|undefined} element - The box being resized.
 * @param {number} [cap] - The ceiling to impose. Defaults to what is left of the
 *   viewport, which is what a box growing downward from the top of the page or
 *   upward from the bottom of it wants.
 * @returns {number} The maximum height in pixels, never above `cap`. A declared
 *   maximum also binds the box, so dragging past it would report a height the box
 *   never takes.
 */
export function measuredMaxHeight(element, cap = viewportCap()) {
  if (!element) {
    return cap;
  }

  const declared = parseInt(getComputedStyle(element).maxHeight, 10);
  return Number.isFinite(declared) ? Math.min(declared, cap) : cap;
}
