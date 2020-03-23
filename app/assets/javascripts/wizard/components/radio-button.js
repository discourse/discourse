import { next } from "@ember/runloop";
import Component from "@ember/component";
import { observes, on } from "discourse-common/utils/decorators";

export default Component.extend({
  tagName: "label",

  click(e) {
    e.preventDefault();
    this.onChange(this.radioValue);
  },

  @observes("value")
  @on("init")
  updateVal() {
    const checked = this.value === this.radioValue;
    next(
      () => (this.element.querySelector("input[type=radio]").checked = checked)
    );
  }
});
