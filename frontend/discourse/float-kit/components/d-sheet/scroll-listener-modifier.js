import { modifier } from "ember-modifier";

/**
 * Modifier that starts RAF polling loop when sheet state is "open".
 *
 * @param {HTMLElement} element - The scroll container element (not used for events, but passed for context)
 * @param {Function} handler - The handler function to call on each frame
 * @param {string} currentState - The current state (controls when polling is active)
 */
export default modifier((element, [handler, currentState]) => {
  if (currentState !== "open") {
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
