import { modifier } from "ember-modifier";

export default modifier((element, [callback], { threshold = 1 }) => {
  const observer = new IntersectionObserver((entries) => {
    entries.forEach(
      (entry) => {
        callback(entry);
      },
      { threshold }
    );
  });

  observer.observe(element);

  return () => {
    observer.disconnect();
  };
});
