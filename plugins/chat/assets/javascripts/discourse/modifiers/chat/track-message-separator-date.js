import Modifier from "ember-modifier";
import { registerDestructor } from "@ember/destroyable";

const IS_PINNED_CLASS = "is-pinned";

/*
  This modifier is used to track the date separator in the chat message list.
  The trick is to have an element with `top: -1px` which will stop fully intersecting
  as soon as it's scrolled a little bit.
*/
export default class ChatTrackMessageSeparatorDate extends Modifier {
  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.cleanup());
  }

  modify(element) {
    this.intersectionObserver = new IntersectionObserver(
      ([event]) => {
        if (event.isIntersecting && event.intersectionRatio < 1) {
          event.target.classList.add(IS_PINNED_CLASS);
        } else {
          event.target.classList.remove(IS_PINNED_CLASS);
        }
      },
      { threshold: [0, 1] }
    );

    this.intersectionObserver.observe(element);
  }

  cleanup() {
    this.intersectionObserver?.disconnect();
  }
}
