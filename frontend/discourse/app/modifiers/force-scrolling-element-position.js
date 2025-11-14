import { registerDestructor } from "@ember/destroyable";
import { service } from "@ember/service";
import Modifier from "ember-modifier";

/**
 * Various touch events or events can cause the scrolling element to
 * scroll in an unexpected way on iOS.
 * This helper, forces the position and checks for it regularly.
 */
export default class forceScrollingElementPosition extends Modifier {
  @service capabilities;

  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.cleanup());
  }

  modify() {
    if (!this.capabilities.isIOS) {
      return;
    }

    // scrolling to 0 doesn't work on safari, you need to scroll to -1
    const offset = window.pageYOffset <= 0 ? -1 : window.pageYOffset;

    window.scrollTo(0, offset);

    this.interval = setInterval(() => {
      window.scrollTo(0, offset);
    }, 50);
  }

  cleanup() {
    if (this.interval) {
      clearInterval(this.interval);
    }
  }
}
