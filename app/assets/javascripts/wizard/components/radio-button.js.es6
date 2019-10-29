import Component from "@ember/component";
import { observes, on } from "ember-addons/ember-computed-decorators";

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
    Ember.run.next(
      () => (this.element.querySelector("input[type=radio]").checked = checked)
    );
  }
});
