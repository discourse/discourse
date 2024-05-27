import Modifier from "ember-modifier";

export default class AutoFocusModifier extends Modifier {
  didFocus = false;

  modify(element, _, { selectText }) {
    if (!this.didFocus) {
      element.autofocus = true;
      element.focus();

      if (selectText) {
        element.select();
      }

      this.didFocus = true;
    }
  }
}
