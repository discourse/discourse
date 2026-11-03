import { modifier } from "ember-modifier";
import { getNext, getPrevious } from "./iterate-list.js";

export default modifier(
  (
    element,
    _,
    { items, highlightedItem, onHighlight, onSelect, onShifSelect }
  ) => {
    const handler = (event) => {
      if (event.key === "ArrowDown") {
        event.preventDefault();
        event.stopPropagation();

        onHighlight(getNext(items, highlightedItem));
      } else if (event.key === "ArrowUp") {
        event.preventDefault();
        event.stopPropagation();

        onHighlight(getPrevious(items, highlightedItem));
      } else if (event.key === "Enter" && highlightedItem) {
        event.preventDefault();
        event.stopPropagation();

        if (event.shiftKey && onShifSelect) {
          onShifSelect(highlightedItem);
        } else {
          onSelect(highlightedItem);
        }
      }
    };

    element.addEventListener("keydown", handler);

    return () => {
      element.removeEventListener("keydown", handler);
    };
  }
);
