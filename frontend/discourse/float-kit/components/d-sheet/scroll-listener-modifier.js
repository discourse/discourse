/**
 * D-Sheet Scroll Listener Modifier
 *
 * Provides a requestAnimationFrame-based polling mechanism for tracking scroll progress
 * in d-sheet components. This approach synchronizes UI updates with the browser's paint
 * cycle, ensuring smooth visual feedback during drag-to-dismiss gestures and scroll
 * interactions. The RAF loop runs only when scroll is actively ongoing, minimizing
 * performance impact during idle states.
 */

import { modifier } from "ember-modifier";

/**
 * Modifier that manages a requestAnimationFrame (RAF) polling loop.
 *
 * This loop is used to synchronize UI state with scroll progress during active
 * scrolling or swiping. By using RAF instead of traditional scroll events,
 * we ensure that position updates are aligned with the browser's paint cycle,
 * providing the smoothest possible interaction.
 *
 * @param {HTMLElement} element - The scroll container element
 * @param {[Function, boolean]} positional - [handler, isScrollOngoing]
 * @returns {Function|undefined} Cleanup function that cancels the RAF loop, or undefined if inactive
 */
export default modifier((element, [handler, isScrollOngoing]) => {
  if (!isScrollOngoing) {
    return;
  }

  /** @type {number|undefined} */
  let rafId;

  /**
   * Recursive RAF callback that invokes the handler and schedules the next frame.
   */
  function loop() {
    handler();
    rafId = requestAnimationFrame(loop);
  }

  loop();

  /**
   * Cleanup function that cancels the active requestAnimationFrame loop.
   */
  return () => {
    if (rafId) {
      cancelAnimationFrame(rafId);
    }
  };
});
