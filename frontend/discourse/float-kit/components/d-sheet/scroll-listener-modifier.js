import { modifier } from "ember-modifier";

/**
 * Modifier that manages a requestAnimationFrame (RAF) polling loop.
 *
 * This loop is used to synchronize UI state with scroll progress during active
 * scrolling or swiping. By using RAF instead of traditional scroll events,
 * we ensure that position updates are aligned with the browser's paint cycle,
 * providing the smoothest possible interaction.
 *
 * This implementation strictly follows the behavior of the internal `no` utility,
 * ensuring immediate first-frame execution to avoid desynchronization lag.
 *
 * @param {HTMLElement} element - The scroll container element
 * @param {Function} handler - The callback to execute on every animation frame
 * @param {boolean} isScrollOngoing - Controls whether the loop is active
 */
export default modifier((element, [handler, isScrollOngoing]) => {
  if (!isScrollOngoing) {
    return;
  }

  let rafId;

  /**
   * Internal loop function that executes the handler and schedules the next frame.
   */
  function loop() {
    handler();
    rafId = requestAnimationFrame(loop);
  }

  rafId = requestAnimationFrame(loop);

  return () => {
    if (rafId) {
      cancelAnimationFrame(rafId);
    }
  };
});
