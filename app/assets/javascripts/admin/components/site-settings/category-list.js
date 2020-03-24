import Component from "@ember/component";
import Category from "discourse/models/category";
import { computed } from "@ember/object";

export default Component.extend({
  selectedCategories: computed("value", function() {
    return Category.findByIds(this.value.split("|").filter(Boolean));
  }),

  actions: {
    onChangeSelectedCategories(value) {
      this.set("value", (value || []).mapBy("id").join("|"));
    }
  }
});
