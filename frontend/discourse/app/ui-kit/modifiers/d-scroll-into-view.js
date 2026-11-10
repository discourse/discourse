import Modifier from "ember-modifier";

/**
 * @typedef ScrollIntoViewSignature
 *
 * @property {object} Args
 * @property {[shouldScroll: boolean, options?: ScrollIntoViewOptions]} Args.Positional
 */

/**
 * Modifier to scroll an element into view when a condition is met
 * Usage: {{scroll-into-view shouldScroll options}}
 *
 * @extends {Modifier<ScrollIntoViewSignature>}
 */
export default class DScrollIntoViewModifier extends Modifier {
  /**
   * @param {Element} element
   * @param {[boolean, ScrollIntoViewOptions?]} positional
   */
  modify(element, [shouldScroll, options = {}]) {
    if (!shouldScroll || !element) {
      return;
    }

    const scrollOptions = {
      behavior: "smooth",
      block: "nearest",
      ...options,
    };

    element.scrollIntoView(scrollOptions);
  }
}
