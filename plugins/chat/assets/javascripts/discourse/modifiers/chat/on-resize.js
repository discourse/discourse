import Modifier from "ember-modifier";
import { registerDestructor } from "@ember/destroyable";
import { cancel, throttle } from "@ember/runloop";

export default class ChatOnResize extends Modifier {
  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.cleanup());
  }

  modify(element, [fn, options = {}]) {
    this.resizeObserver = new ResizeObserver((entries) => {
      this.throttleHandler = throttle(
        this,
        fn,
        entries,
        options.delay ?? 0,
        options.immediate ?? false
      );
    });

    this.resizeObserver.observe(element);
  }

  cleanup() {
    cancel(this.throttleHandler);
    this.resizeObserver?.disconnect();
  }
}
