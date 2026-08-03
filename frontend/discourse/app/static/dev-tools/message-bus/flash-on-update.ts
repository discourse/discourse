import { modifier } from "ember-modifier";

const previousValues = new WeakMap<HTMLElement, number | null>();

export default modifier(
  (element: HTMLElement, [lastMessageAt]: [number | null]) => {
    const previous = previousValues.get(element);

    if (
      previousValues.has(element) &&
      previous !== null &&
      lastMessageAt !== null &&
      lastMessageAt > previous
    ) {
      element.dataset.testWasHighlighted = "true";
      element.addEventListener(
        "animationend",
        () => element.classList.remove("highlighted"),
        { once: true }
      );
      element.classList.add("highlighted");
    }

    previousValues.set(element, lastMessageAt);
  }
);
