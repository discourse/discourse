import { registerDestructor } from "@ember/destroyable";
import { cancel } from "@ember/runloop";
import Modifier from "ember-modifier";
import discourseLater from "discourse/lib/later";

export default class ChatLaterFn extends Modifier {
  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.cleanup());
  }

  modify(element, [fn, delay]) {
    this.handler = discourseLater(() => {
      fn?.(element);
    }, delay);
  }

  cleanup() {
    cancel(this.handler);
  }
}
