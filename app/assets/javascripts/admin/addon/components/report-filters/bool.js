import { action } from "@ember/object";
import FilterComponent from "admin/components/report-filters/filter";

export default class Bool extends FilterComponent {
  checked = false;

  didReceiveAttrs() {
    super.didReceiveAttrs(...arguments);
    this.set("checked", !!this.filter.default);
  }

  @action
  onChange() {
    this.applyFilter(this.filter.id, !this.checked || undefined);
  }
}
