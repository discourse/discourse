import Modifier from "ember-modifier";

interface DScrollIntoViewSignature {
  Element: Element;
  Args: {
    Positional: [
      /** Whether to scroll the element into view. */
      shouldScroll: boolean,
      /** Options merged over the defaults of a smooth scroll to the nearest edge. */
      options?: ScrollIntoViewOptions,
    ];
  };
}

/**
 * Modifier to scroll an element into view when a condition is met
 * Usage: `{{dScrollIntoView shouldScroll options}}`
 */
export default class DScrollIntoViewModifier extends Modifier<DScrollIntoViewSignature> {
  /**
   * @param element - The element to scroll into view.
   * @param positional - The condition and the scroll options.
   */
  modify(
    element: Element,
    [shouldScroll, options = {}]: DScrollIntoViewSignature["Args"]["Positional"]
  ) {
    if (!shouldScroll || !element) {
      return;
    }

    const scrollOptions: ScrollIntoViewOptions = {
      behavior: "smooth",
      block: "nearest",
      ...options,
    };

    element.scrollIntoView(scrollOptions);
  }
}
