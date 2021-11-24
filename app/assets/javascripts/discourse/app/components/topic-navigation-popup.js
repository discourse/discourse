import Component from "@ember/component";
import { action } from "@ember/object";

export default Component.extend({
  hidden: false,

  @action
  close() {
    this.set("hidden", true);
  },
});
