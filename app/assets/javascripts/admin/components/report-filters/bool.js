import FilterComponent from "admin/components/report-filters/filter";

export default FilterComponent.extend({
  checked: false,

  didReceiveAttrs() {
    this.set("checked", !!this.filter.default);
  },

  actions: {
    onChange() {
      this.applyFilter(this.filter.id, !this.checked || undefined);
    }
  }
});
