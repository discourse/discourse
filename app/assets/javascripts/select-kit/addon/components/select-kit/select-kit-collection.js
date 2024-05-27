import { cached } from "@glimmer/tracking";
import Component from "@ember/component";
import { action } from "@ember/object";
import {
  disableBodyScroll,
  enableBodyScroll,
} from "discourse/lib/body-scroll-lock";

export default Component.extend({
  tagName: "",

  @cached
  get inModal() {
    const element = this.selectKit.mainElement();
    return element.closest(".d-modal");
  },

  @action
  lock(element) {
    if (!this.inModal) {
      return;
    }

    disableBodyScroll(element);
  },

  @action
  unlock(element) {
    enableBodyScroll(element);
  },
});
