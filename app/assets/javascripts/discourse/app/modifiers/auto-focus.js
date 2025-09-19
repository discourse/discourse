import { schedule } from "@ember/runloop";
import Modifier from "ember-modifier";

export default class AutoFocusModifier extends Modifier {
  didFocus = false;

  modify(element, _, { selectText }) {
    schedule("afterRender", () => {
      if (!this.didFocus) {
        element.autofocus = true;
        element.focus();

        if (selectText) {
          element.select();
        }

        this.didFocus = true;
      }
    });
  }
}
