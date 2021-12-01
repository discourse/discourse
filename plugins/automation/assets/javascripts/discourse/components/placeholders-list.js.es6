import Component from "@ember/component";
import { action } from "@ember/object";

export default Component.extend({
  tagName: "",
  targetId: null,

  @action
  copyPlaceholder(placeholder) {
    // const target = document.querySelector(`#${this.targetId}`);
    // target.value = target.value + ` %%${placeholder.toUpperCase()}%%`;

    this.set(
      "currentValue",
      this.currentValue + ` %%${placeholder.toUpperCase()}%%`
    );
  }
});
