import Category from "discourse/models/category";
import discourseComputed from "discourse-common/utils/decorators";
import FilterComponent from "admin/components/report-filters/filter";

export default FilterComponent.extend({
  classNames: ["category-filter"],

  layoutName: "admin/templates/components/report-filters/category",

  @discourseComputed("filter.default")
  category(categoryId) {
    return Category.findById(categoryId);
  },

  actions: {
    onDeselect() {
      this.applyFilter(this.get("filter.id"), undefined);
    }
  }
});
