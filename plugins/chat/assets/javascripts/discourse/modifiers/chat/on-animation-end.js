import { registerDestructor } from "@ember/destroyable";
import { cancel, schedule } from "@ember/runloop";
import Modifier from "ember-modifier";
import { bind } from "discourse/lib/decorators";

export default class ChatOnAnimationEnd extends Modifier {
  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.cleanup());
  }

  modify(element, [fn]) {
    this.element = element;
    this.fn = fn;

    this.handler = schedule("afterRender", () => {
      this.element.addEventListener("animationend", this.handleAnimationEnd);
    });
  }

  @bind
  handleAnimationEnd() {
    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    this.fn?.(this.element);
  }

  cleanup() {
    cancel(this.handler);
    this.element?.removeEventListener("animationend", this.handleAnimationEnd);
  }
}
