import Component from "@ember/component";
import computed from "ember-addons/ember-computed-decorators";

export default Component.extend({
  classNameBindings: [
    ":loading-container",
    "containerClass",
    "condition:visible"
  ],

  @computed("size")
  containerClass(size) {
    return size === "small" ? "inline-spinner" : undefined;
  }
});
