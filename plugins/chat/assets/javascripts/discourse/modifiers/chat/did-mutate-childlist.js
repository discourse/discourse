import Modifier from "ember-modifier";
import { registerDestructor } from "@ember/destroyable";

export default class ChatDidMutateChildlist extends Modifier {
  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.cleanup());
  }

  modify(element, [callback]) {
    this.mutationObserver = new MutationObserver(() => {
      callback();
    });

    this.mutationObserver.observe(element, {
      childList: true,
      subtree: true,
    });
  }

  cleanup() {
    this.mutationObserver?.disconnect();
  }
}
