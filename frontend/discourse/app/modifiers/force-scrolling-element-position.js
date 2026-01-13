import { registerDestructor } from "@ember/destroyable";
import { service } from "@ember/service";
import Modifier from "ember-modifier";
import { bind } from "discourse/lib/decorators";

/**
 * Various touch events or events can cause the scrolling element to
 * scroll in an unexpected way on iOS.
 * This helper, forces the position each time the keyboard is opened.
 */
export default class forceScrollingElementPosition extends Modifier {
  @service appEvents;
  @service capabilities;

  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.cleanup());
  }

  modify() {
    if (!this.capabilities.isIOS) {
      return;
    }

    this.appEvents.on(
      "keyboard-visibility-change",
      this,
      this.handleKeyboardVisibility
    );
  }

  cleanup() {
    if (!this.capabilities.isIOS) {
      return;
    }

    this.appEvents.off(
      "keyboard-visibility-change",
      this,
      this.handleKeyboardVisibility
    );
  }

  @bind
  handleKeyboardVisibility(isVisible) {
    // we use 100 and not 0 as most likely if under 100 this is a position error
    if (isVisible && window.pageYOffset <= 100) {
      // on iOS scrolling to 0 doesn’t work correctly
      // scrolling to -1 is more consistent
      window.scrollTo(0, -1);
    }
  }
}
