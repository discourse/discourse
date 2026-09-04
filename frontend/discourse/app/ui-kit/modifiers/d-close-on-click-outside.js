import { registerDestructor } from "@ember/destroyable";
import Modifier from "ember-modifier";
import { bind } from "discourse/lib/decorators";

export default class DCloseOnClickOutside extends Modifier {
  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.cleanup());
  }

  modify(
    element,
    [closeFn, { targetSelector, secondaryTargetSelector, target } = {}]
  ) {
    this.closeFn = closeFn;
    this.element = element;
    this.target = target;
    this.targetSelector = targetSelector;
    this.secondaryTargetSelector = secondaryTargetSelector;

    element.ownerDocument.addEventListener("pointerdown", this.check, {
      passive: true,
    });
  }

  @bind
  check(event) {
    if (this.element.contains(event.target)) {
      return;
    }

    const target =
      this.target ??
      this.element.ownerDocument.querySelector(this.targetSelector);

    if (
      target?.contains(event.target) ||
      (this.secondaryTargetSelector &&
        this.element.ownerDocument
          .querySelector(this.secondaryTargetSelector)
          ?.contains(event.target))
    ) {
      return;
    }

    this.closeFn(event);
  }

  cleanup() {
    // A modifier destroyed before it ever modified has no element to ask.
    this.element?.ownerDocument.removeEventListener("pointerdown", this.check, {
      passive: true,
    });
  }
}
