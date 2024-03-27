import Component from "@ember/component";
import { action } from "@ember/object";
import {
  disableBodyScroll,
  enableBodyScroll,
} from "discourse/lib/body-scroll-lock";

export default Component.extend({
  tagName: "",

  @action
  lock(element) {
    disableBodyScroll(element);
  },

  @action
  unlock(element) {
    enableBodyScroll(element);
  },
});
