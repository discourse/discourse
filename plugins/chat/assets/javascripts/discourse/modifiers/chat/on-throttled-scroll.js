import Modifier from "ember-modifier";
import { registerDestructor } from "@ember/destroyable";
import { cancel, throttle } from "@ember/runloop";
import { bind } from "discourse-common/utils/decorators";

export default class ChatOnThrottledScroll extends Modifier {
  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.cleanup());
  }

  modify(element, [callback, options]) {
    this.element = element;
    this.callback = callback;
    this.options = options;
    this.element.addEventListener("scroll", this.throttledCallback, {
      passive: true,
    });
  }

  @bind
  throttledCallback(event) {
    this.throttledHandler = throttle(
      this,
      this.callback,
      event,
      this.options.delay ?? 100,
      this.options.immediate ?? false
    );
  }

  cleanup() {
    cancel(this.throttledHandler);
    this.element.removeEventListener("scroll", this.throttledCallback);
  }
}
