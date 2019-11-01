import Component from "@ember/component";
import computed from "ember-addons/ember-computed-decorators";

export default Component.extend({
  @computed("value")
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
