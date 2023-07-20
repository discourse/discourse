import { classNames } from "@ember-decorators/component";
import { computed } from "@ember/object";
import FilterComponent from "admin/components/report-filters/filter";

@classNames("group-filter")
export default class Group extends FilterComponent {
  @computed
  get groupOptions() {
    return (this.site.groups || []).map((group) => {
      return { name: group["name"], value: group["id"] };
    });
  }

  @computed("filter.default")
  get groupId() {
    return this.filter.default ? parseInt(this.filter.default, 10) : null;
  }
}
