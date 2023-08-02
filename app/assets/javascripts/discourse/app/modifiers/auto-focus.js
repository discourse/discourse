import Modifier from "ember-modifier";

export default class AutoFocusModifier extends Modifier {
  didFocus = false;

  modify(element) {
    if (!this.didFocus) {
      element.autofocus = true;
      element.focus();

      this.didFocus = true;
    }
  }
}
