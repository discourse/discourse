import { registerDestructor } from "@ember/destroyable";
import Modifier from "ember-modifier";
import { bind } from "discourse-common/utils/decorators";

export default class CloseOnClickOutside extends Modifier {
  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.cleanup());
  }

  modify(element, [closeFn, { targetSelector, secondaryTargetSelector }]) {
    this.closeFn = closeFn;
    this.element = element;
    this.targetSelector = targetSelector;
    this.secondaryTargetSelector = secondaryTargetSelector;

    document.addEventListener("pointerdown", this.check, {
      passive: true,
    });
  }

  @bind
  check(event) {
    if (this.element.contains(event.target)) {
      return;
    }

    if (
      document.querySelector(this.targetSelector)?.contains(event.target) ||
      (this.secondaryTargetSelector &&
        document
          .querySelector(this.secondaryTargetSelector)
          ?.contains(event.target))
    ) {
      return;
    }

    this.closeFn(event);
  }

  cleanup() {
    document.removeEventListener("pointerdown", this.check);
  }
}
