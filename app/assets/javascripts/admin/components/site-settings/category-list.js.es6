import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";
import Category from "discourse/models/category";

export default Component.extend({
  @discourseComputed("value")
  selectedCategories: {
    get(value) {
      return Category.findByIds(value.split("|"));
    },
    set(value) {
      this.set("value", value.mapBy("id").join("|"));
      return value;
    }
  }
});
