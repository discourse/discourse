import Category from "discourse/models/category";
import { default as computed } from "ember-addons/ember-computed-decorators";
import FilterComponent from "admin/components/report-filters/filter";

export default FilterComponent.extend({
  classNames: ["category-filter"],

  layoutName: "admin/templates/components/report-filters/category",

  @computed("filter.default")
  category(categoryId) {
    return Category.findById(categoryId);
  },

  actions: {
    onDeselect() {
      this.applyFilter(this.get("filter.id"), undefined);
    }
  }
});
