import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  tagName: "",
  size: null,
  condition: null,

  @discourseComputed("size")
  containerClass(size) {
    return size === "small" ? "inline-spinner" : undefined;
  },
});
