import { registerDestructor } from "@ember/destroyable";
import Modifier from "ember-modifier";
import { bind } from "discourse-common/utils/decorators";

export default class CloseOnClickOutside extends Modifier {
  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.cleanup());
  }

  modify(
    element,
    [closeFn, { targetSelector, secondaryTargetSelector, target }]
  ) {
    this.closeFn = closeFn;
    this.element = element;
    this.target = target;
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

    const target = this.target ?? document.querySelector(this.targetSelector);

    if (
      target?.contains(event.target) ||
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
    document.removeEventListener("pointerdown", this.check, {
      passive: true,
    });
  }
}
