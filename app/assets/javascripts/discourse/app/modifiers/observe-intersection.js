import { modifier } from "ember-modifier";

export default modifier((element, [callback], { threshold = 1 }) => {
  const observer = new IntersectionObserver((entries) => {
    entries.forEach(callback, { threshold });
  });

  observer.observe(element);

  return () => {
    observer.disconnect();
  };
});
