import Modifier from "ember-modifier";

export default class AutoFocusModifier extends Modifier {
  didFocus = false;

  modify(element, _, { selectText, preventScroll }) {
    if (!this.didFocus) {
      element.autofocus = true;
      element.focus({ preventScroll: preventScroll ?? true });

      if (selectText) {
        element.select();
      }

      this.didFocus = true;
    }
  }
}
