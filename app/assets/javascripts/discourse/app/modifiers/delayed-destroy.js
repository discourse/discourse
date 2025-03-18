import { modifier } from "ember-modifier";
import discourseLater from "discourse/lib/later";

/**
 * A modifier that handles delayed destruction of elements allowing animation to run.
 * @param {HTMLElement} element - The element to be modified
 * @param {Array} posArgs - Positional arguments (unused)
 * @param {Object} namedArgs - Named arguments
 * @param {boolean} [namedArgs.animate=false] - Whether to animate the destruction
 * @param {Function} [namedArgs.onComplete=()=>{}] - Callback function to execute after destruction
 * @param {string} [namedArgs.elementSelector] - Optional CSS selector to target a child element
 * @param {number} [namedArgs.delay=300] - Delay in milliseconds before completing destruction
 */
export default modifier(
  (
    element,
    posArgs,
    { animate = false, onComplete = () => {}, elementSelector, delay = 300 }
  ) => {
    if (animate) {
      const targetEl = elementSelector
        ? element.querySelector(elementSelector)
        : element;
      targetEl?.classList.add("is-destroying");

      discourseLater(() => {
        targetEl?.classList.remove("is-destroying");
        onComplete();
      }, delay);
    }
  }
);
