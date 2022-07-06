import Category from "discourse/models/category";
import Component from "@ember/component";
import { computed } from "@ember/object";

export default Component.extend({
  tagName: "",

  selectedCategories: computed("value", function () {
    return Category.findByIds(this.value.split("|").filter(Boolean));
  }),

  actions: {
    onChangeSelectedCategories(value) {
      this.set("value", (value || []).mapBy("id").join("|"));
    },
  },
});
