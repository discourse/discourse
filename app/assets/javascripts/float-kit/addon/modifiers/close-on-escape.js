import { registerDestructor } from "@ember/destroyable";
import Modifier from "ember-modifier";
import { bind } from "discourse-common/utils/decorators";

export default class FloatKitCloseOnEscape extends Modifier {
  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.cleanup());
  }

  modify(element, [closeFn]) {
    this.closeFn = closeFn;
    this.element = element;

    document.addEventListener("keydown", this.check, { capture: true });
  }

  @bind
  check(event) {
    if (event.key === "Escape") {
      event.stopPropagation();
      event.preventDefault();
      this.closeFn();
    }
  }

  cleanup() {
    document.removeEventListener("keydown", this.check, { capture: true });
  }
}
