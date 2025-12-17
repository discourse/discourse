import { modifier } from "ember-modifier";

/**
 * Modifier that starts RAF polling loop when sheet state is "open".
 * Like Silk's no() function which uses RAF polling instead of scroll events.
 *
 * This avoids Firefox's spurious scroll event bug where scrollTop=0 is reported
 * immediately when adding a scroll listener.
 *
 * @param {HTMLElement} element - The scroll container element (not used for events, but passed for context)
 * @param {Function} handler - The handler function to call on each frame
 * @param {string} currentState - The current state (controls when polling is active)
 */
export default modifier((element, [handler, currentState]) => {
  // eslint-disable-next-line no-console
  console.log(`[scrollListenerModifier] currentState:${currentState}`);

  if (currentState !== "open") {
    // eslint-disable-next-line no-console
    console.log(
      `[scrollListenerModifier] NOT starting RAF (state is not open)`
    );
    return;
  }

  // Use RAF polling like Silk's no() function
  let rafId;

  function loop() {
    handler(); // Poll progress on each frame
    rafId = requestAnimationFrame(loop);
  }

  // Start on next frame to avoid state updates during rendering
  // eslint-disable-next-line no-console
  console.log(`[scrollListenerModifier] STARTING RAF polling loop`);
  rafId = requestAnimationFrame(loop);

  return () => {
    // eslint-disable-next-line no-console
    console.log(`[scrollListenerModifier] STOPPING RAF polling loop`);
    cancelAnimationFrame(rafId);
  };
});
