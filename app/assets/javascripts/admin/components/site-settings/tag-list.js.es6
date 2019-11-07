import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";

export default Component.extend({
  @discourseComputed("value")
  selectedTags: {
    get(value) {
      return value.split("|");
    },
    set(value) {
      this.set("value", value.join("|"));
      return value;
    }
  }
});
