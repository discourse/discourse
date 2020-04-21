import { computed } from "@ember/object";
import FilterComponent from "admin/components/report-filters/filter";

export default FilterComponent.extend({
  classNames: ["group-filter"],

  @computed
  get groupOptions() {
    return (this.site.groups || []).map(group => {
      return { name: group["name"], value: group["id"] };
    });
  },

  @computed("filter.default")
  get groupId() {
    return this.filter.default ? parseInt(this.filter.default, 10) : null;
  }
});
