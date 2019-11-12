import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";

export default Component.extend({
  classNameBindings: [
    ":loading-container",
    "containerClass",
    "condition:visible"
  ],

  @discourseComputed("size")
  containerClass(size) {
    return size === "small" ? "inline-spinner" : undefined;
  }
});
