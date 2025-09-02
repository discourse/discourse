import Modifier from "ember-modifier";

/**
 * Modifier to scroll an element into view when a condition is met
 * Usage: {{scroll-into-view shouldScroll options}}
 *
 * @param {boolean} shouldScroll - Whether to scroll this element into view
 * @param {Object} options - ScrollIntoView options (behavior, block, inline)
 */
export default class ScrollIntoViewModifier extends Modifier {
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
