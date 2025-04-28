import { modifier } from "ember-modifier";

export default modifier(
  (
    element,
    [callback],
    { threshold = 1, rootMargin = "0px 0px 0px 0px", root = null }
  ) => {
    const rootElement = root ? document.querySelector(root) : null;

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
