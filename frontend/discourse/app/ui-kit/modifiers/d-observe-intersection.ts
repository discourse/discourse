import { modifier } from "ember-modifier";

interface DObserveIntersectionSignature {
  Element: Element;
  Args: {
    Positional: [
      /** Called with each entry the observer reports for the element. */
      callback: (entry: IntersectionObserverEntry) => void,
    ];
    Named: {
      /** The visible fraction, or fractions, that report an entry. Defaults to `1`. */
      threshold?: number | number[];
      /**
       * The margin around the root, as a CSS margin string or as an array of sides. Numbers
       * in the array are pixel lengths. Defaults to `"0px 0px 0px 0px"`.
       */
      rootMargin?: string | (string | number)[];
      /**
       * The element to observe intersection within, or a selector for it. A selector only
       * resolves when the root is already mounted. When omitted, the document is the root.
       */
      root?: string | Element | null;
      /** Whether to skip observing, such as while more content is loading. */
      isLoading?: boolean;
    };
  };
}

/**
 * Calls `callback` whenever the element's visible fraction within the root crosses a
 * threshold. Disconnects the observer on teardown.
 */
export default modifier<DObserveIntersectionSignature>(
  (
    element,
    [callback],
    {
      threshold = 1,
      rootMargin = "0px 0px 0px 0px",
      root = null,
      isLoading = false,
    }
  ) => {
    if (isLoading) {
      return () => {};
    }

    if (Array.isArray(rootMargin)) {
      rootMargin = rootMargin
        .map((margin) => (typeof margin === "number" ? `${margin}px` : margin))
        .join(" ");
    }

    // A selector is resolved against the live document, so it only works once the root is
    // already mounted. An element can be handed over directly, which is the only race-free
    // option when the root and the observed node mount in the same render.
    let rootElement: Element | Document | null = document;
    if (root) {
      rootElement =
        typeof root === "string" ? document.querySelector(root) : root;
    }

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach(callback);
      },
      { threshold, rootMargin, root: rootElement }
    );

    observer.observe(element);

    return () => {
      observer.disconnect();
    };
  }
);
