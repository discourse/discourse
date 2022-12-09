import Modifier from "ember-modifier";
import { inject as service } from "@ember/service";
import { registerDestructor } from "@ember/destroyable";

export default class TrackMessageVisibility extends Modifier {
  @service chatMessageVisibilityObserver;

  element = null;

  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.cleanup());
  }

  modify(element) {
    this.element = element;
    this.chatMessageVisibilityObserver.observe(element);
  }

  cleanup() {
    this.chatMessageVisibilityObserver.unobserve(this.element);
  }
}
