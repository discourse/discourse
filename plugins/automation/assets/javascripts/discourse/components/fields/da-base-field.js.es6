import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  tagName: "",
  placeholders: null,
  field: null,

  @discourseComputed("placeholders.length", "field.acceptsPlaceholders")
  displayPlaceholders(hasPlaceholders, acceptsPlaceholders) {
    return hasPlaceholders && acceptsPlaceholders;
  }
});
