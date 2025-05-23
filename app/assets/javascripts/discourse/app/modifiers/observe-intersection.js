import { modifier } from "ember-modifier";

export default modifier(
  (
    element,
    [callback],
    { threshold = 1, rootMargin = "0px 0px 0px 0px", root = null }
  ) => {
    if (Array.isArray(rootMargin)) {
      rootMargin = rootMargin
        .map((margin) => (typeof margin === "number" ? `${margin}px` : margin))
        .join(" ");
    }

    const rootElement = root ? document.querySelector(root) : document;

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
