import Modifier from "ember-modifier";

/**
 * @typedef ScrollIntoViewSignature
 *
 * @property {object} Args
 * @property {Array} Args.Positional
 * @property {boolean} Args.Positional.0 - Whether to scroll this element into view
 * @property {ScrollIntoViewOptions} [Args.Positional.1] - ScrollIntoView options (behavior, block, inline)
 */

/**
 * Modifier to scroll an element into view when a condition is met
 * Usage: {{scroll-into-view shouldScroll options}}
 *
 * @extends {Modifier<ScrollIntoViewSignature>}
 */
export default class ScrollIntoViewModifier extends Modifier {
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
