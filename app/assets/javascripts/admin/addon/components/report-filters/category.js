import { action } from "@ember/object";
import { readOnly } from "@ember/object/computed";
import FilterComponent from "admin/components/report-filters/filter";

export default class Category extends FilterComponent {
  @readOnly("filter.default") category;

  @action
  onChange(categoryId) {
    this.applyFilter(this.filter.id, categoryId || undefined);
  }
}
