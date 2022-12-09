import Modifier from "ember-modifier";
import { inject as service } from "@ember/service";
import { registerDestructor } from "@ember/destroyable";

export default class EmojiPickerScrollListener extends Modifier {
  @service emojiPickerScrollObserver;

  element = null;

  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.cleanup());
  }

  modify(element) {
    this.element = element;
    this.emojiPickerScrollObserver.observe(element);
  }

  cleanup() {
    this.emojiPickerScrollObserver.unobserve(this.element);
  }
}
