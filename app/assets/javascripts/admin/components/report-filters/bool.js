import { action } from "@ember/object";
import FilterComponent from "admin/components/report-filters/filter";

export default FilterComponent.extend({
  checked: false,

  didReceiveAttrs() {
    this._super(...arguments);
    this.set("checked", !!this.filter.default);
  },

  @action
  onChange() {
    this.applyFilter(this.filter.id, !this.checked || undefined);
  }
});
