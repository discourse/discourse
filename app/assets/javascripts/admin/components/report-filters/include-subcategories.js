import FilterComponent from "admin/components/report-filters/filter";
import discourseComputed from "discourse-common/utils/decorators";

export default FilterComponent.extend({
  checked: false,

  didReceiveAttrs() {
    this.set("checked", this.filter.default === "true");
  },

  @discourseComputed()
  disabled() {
    return this.model.available_filters.any(
      filter => filter.id === "category" && !filter.default
    );
  },

  actions: {
    onChange() {
      this.applyFilter(this.get("filter.id"), !this.checked ? "true" : "false");
    }
  }
});
