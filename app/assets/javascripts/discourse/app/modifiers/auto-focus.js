import Modifier from "ember-modifier";

export default class AutoFocusModifier extends Modifier {
  didFocus = false;

  modify(element, _, { cursorPosition }) {
    if (this.didFocus) {
      return;
    }

    if (cursorPosition === "end") {
      const end = element.value.length;
      element.setSelectionRange(end, end);
    }

    element.focus();
    this.didFocus = true;
  }
}
