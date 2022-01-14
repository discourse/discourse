import Component from "@ember/component";
import { action } from "@ember/object";

export default Component.extend({
  tagName: "",
  targetId: null,

  @action
  copyPlaceholder(placeholder) {
    this.set(
      "currentValue",
      this.currentValue + ` %%${placeholder.toUpperCase()}%%`
    );
  },
});
