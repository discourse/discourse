import { readOnly } from "@ember/object/computed";
import FilterComponent from "admin/components/report-filters/filter";

export default FilterComponent.extend({
  classNames: ["category-filter"],

  layoutName: "admin/templates/components/report-filters/category",

  category: readOnly("filter.default"),

  actions: {
    onChange(categoryId) {
      this.applyFilter(this.get("filter.id"), categoryId || undefined);
    }
  }
});
