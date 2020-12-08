import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  classNameBindings: [
    ":loading-container",
    "containerClass",
    "condition:visible",
  ],

  @discourseComputed("size")
  containerClass(size) {
    return size === "small" ? "inline-spinner" : undefined;
  },
});
