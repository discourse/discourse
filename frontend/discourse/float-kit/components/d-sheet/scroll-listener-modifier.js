import { modifier } from "ember-modifier";

/**
 * Modifier that attaches scroll listener only when sheet state is "open".
 *
 * @param {HTMLElement} element - The element to attach the scroll listener to
 * @param {Function} handler - The scroll handler function
 * @param {string} currentState - The current state (controls when listener is attached)
 */
export default modifier((element, [handler, currentState]) => {
  if (currentState !== "open") {
    return;
  }

  let skipFirst = true;

  const wrappedHandler = () => {
    if (skipFirst) {
      skipFirst = false;
      return;
    }
    handler();
  };

  element.addEventListener("scroll", wrappedHandler, { passive: true });

  return () => {
    element.removeEventListener("scroll", wrappedHandler);
  };
});
