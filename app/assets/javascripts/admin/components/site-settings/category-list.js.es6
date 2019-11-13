import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";

export default Component.extend({
  @discourseComputed("value")
  selectedCategories: {
    get(value) {
      return Discourse.Category.findByIds(value.split("|"));
    },
    set(value) {
      this.set("value", value.mapBy("id").join("|"));
      return value;
    }
  }
});
