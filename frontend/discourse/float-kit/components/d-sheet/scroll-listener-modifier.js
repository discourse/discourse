import { modifier } from "ember-modifier";

/**
 * Modifier that starts RAF polling loop when scroll is ongoing.
 *
 * @param {HTMLElement} element - The scroll container element
 * @param {Function} handler - The handler function to call on each frame
 * @param {boolean} isScrollOngoing - Whether scroll is currently ongoing
 */
export default modifier((element, [handler, isScrollOngoing]) => {
  if (!isScrollOngoing) {
    return;
  }

  let rafId;

  function loop() {
    handler();
    rafId = requestAnimationFrame(loop);
  }

  requestAnimationFrame(() => {
    loop();
  });

  return () => {
    cancelAnimationFrame(rafId);
  };
});
