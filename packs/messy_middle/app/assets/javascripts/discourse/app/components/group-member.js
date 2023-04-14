import Component from "@ember/component";
import { action } from "@ember/object";

export default Component.extend({
  classNames: ["item"],

  @action
  remove(event) {
    event?.preventDefault();
    this.removeAction(this.member);
  },
});
