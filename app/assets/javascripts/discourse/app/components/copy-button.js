import Component from "@ember/component";
import { action } from "@ember/object";

export default Component.extend({
  tagName: "",

  @action
  copy() {
    const target = document.querySelector(this.selector);
    target.select();
    target.setSelectionRange(0, target.value.length);
    try {
      document.execCommand("copy");
      if (this.copied) {
        this.copied();
      }
    } catch (err) {}
  },
});
