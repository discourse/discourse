import { modifier } from "ember-modifier";

export default modifier(
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
    let rootElement = document;
    if (typeof root === "string") {
      rootElement = document.querySelector(root);
    } else if (root) {
      rootElement = root;
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
