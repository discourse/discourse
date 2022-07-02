import Component from "@ember/component";
import { action } from "@ember/object";

export default Component.extend({
  tagName: "",

  @action
  expand() {
    this.set("expanded", true);
  }
});
